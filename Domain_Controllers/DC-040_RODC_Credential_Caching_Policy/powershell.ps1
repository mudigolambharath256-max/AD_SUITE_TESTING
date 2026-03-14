# =============================================================================
# DC-040: RODC Credential Caching Policy
# =============================================================================
# Category: Domain Controllers
# Severity: HIGH
# ID: DC-040
# MITRE: T1552.004 (Unsecured Credentials: Private Keys)
# =============================================================================
# Description: Detects Read-Only Domain Controllers (RODCs) with insecure
#              credential caching policies that may allow privileged account
#              credentials to be cached and compromised.
# =============================================================================
# LDAP Filter: (&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=67108864))
# Search Base: Default NC
# Object Class: computer
# Attributes: name, distinguishedName, dNSHostName, msDS-NeverRevealGroup,
#             msDS-RevealOnDemandGroup, msDS-RevealedList, msDS-KrbTgtLinkBl
# =============================================================================

param(
    [string]$SearchBase,
    [string]$Server
)

$ErrorActionPreference = 'Continue'

try {
    Import-Module ActiveDirectory -ErrorAction Stop

    # Get all domains in the forest for comprehensive RODC detection
    $forest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
    $allResults = @()

    foreach ($domain in $forest.Domains) {
        Write-Host "Checking domain: $($domain.Name)" -ForegroundColor Cyan

        try {
            $domainDN = "DC=$($domain.Name.Replace('.', ',DC='))"
            $searchBase = if ($SearchBase) { $SearchBase } else { $domainDN }

            # Find RODCs using UAC bit 67108864 (PARTIAL_SECRETS_ACCOUNT)
            $rodcs = Get-ADComputer -Server $domain.Name `
                                   -Filter "userAccountControl -band 67108864" `
                                   -Properties name,distinguishedName,dNSHostName,msDS-NeverRevealGroup,msDS-RevealOnDemandGroup,msDS-RevealedList,msDS-KrbTgtLinkBl ,objectSid `
                                   -SearchBase $searchBase `
                                   -ErrorAction Stop

            Write-Host "  Found $($rodcs.Count) RODCs in $($domain.Name)" -ForegroundColor Green

            if ($rodcs.Count -eq 0) {
                Write-Host "  No RODCs found in domain $($domain.Name)" -ForegroundColor Gray
                continue
            }

            # Define privileged groups that should NEVER be cached on RODCs
            $privilegedGroups = @(
                "CN=Domain Admins,CN=Users,$domainDN",
                "CN=Enterprise Admins,CN=Users,$domainDN",
                "CN=Schema Admins,CN=Users,$domainDN",
                "CN=Administrators,CN=Builtin,$domainDN",
                "CN=Group Policy Creator Owners,CN=Users,$domainDN",
                "CN=Domain Controllers,CN=Users,$domainDN",
                "CN=Denied RODC Password Replication Group,CN=Users,$domainDN"
            )

            foreach ($rodc in $rodcs) {
                $issues = @()
                $severity = "HIGH"

                # Check msDS-NeverRevealGroup (accounts that should NEVER be cached)
                $neverRevealGroups = @()
                if ($rodc.'msDS-NeverRevealGroup') {
                    $neverRevealGroups = $rodc.'msDS-NeverRevealGroup'
                }

                # Check if all privileged groups are in NeverRevealGroup
                $missingPrivilegedGroups = @()
                foreach ($privGroup in $privilegedGroups) {
                    if ($neverRevealGroups -notcontains $privGroup) {
                        $groupName = ($privGroup -replace '^CN=([^,]+),.*', '$1')
                        $missingPrivilegedGroups += $groupName
                    }
                }

                if ($missingPrivilegedGroups.Count -gt 0) {
                    $issues += "Privileged groups not in NeverRevealGroup: $($missingPrivilegedGroups -join ', ')"
                    $severity = "CRITICAL"
                }

                # Check msDS-RevealedList (accounts whose credentials ARE currently cached)
                $revealedAccounts = @()
                if ($rodc.'msDS-RevealedList') {
                    $revealedAccounts = $rodc.'msDS-RevealedList'
                }

                if ($revealedAccounts.Count -gt 0) {
                    # Check if any revealed accounts are privileged
                    $privilegedRevealed = @()
                    foreach ($accountDN in $revealedAccounts) {
                        try {
                            $account = Get-ADObject -Server $domain.Name -Identity $accountDN -Properties samAccountName,adminCount -ErrorAction SilentlyContinue,objectSid
                            if ($account -and $account.adminCount -eq 1) {
                                $privilegedRevealed += $account.samAccountName
                            }
                        } catch {
                            # Account lookup failed, continue
                        }
                    }

                    if ($privilegedRevealed.Count -gt 0) {
                        $issues += "Privileged accounts cached on RODC: $($privilegedRevealed -join ', ')"
                        $severity = "CRITICAL"
                    }

                    $issues += "Total accounts with cached credentials: $($revealedAccounts.Count)"
                }

                # Check msDS-RevealOnDemandGroup (accounts that CAN be cached)
                $revealOnDemandGroups = @()
                if ($rodc.'msDS-RevealOnDemandGroup') {
                    $revealOnDemandGroups = $rodc.'msDS-RevealOnDemandGroup'

                    # Check if any privileged groups are in RevealOnDemandGroup (should not be)
                    $privilegedInRevealOnDemand = @()
                    foreach ($privGroup in $privilegedGroups) {
                        if ($revealOnDemandGroups -contains $privGroup) {
                            $groupName = ($privGroup -replace '^CN=([^,]+),.*', '$1')
                            $privilegedInRevealOnDemand += $groupName
                        }
                    }

                    if ($privilegedInRevealOnDemand.Count -gt 0) {
                        $issues += "Privileged groups in RevealOnDemandGroup: $($privilegedInRevealOnDemand -join ', ')"
                        $severity = "CRITICAL"
                    }
                }

                if ($issues.Count -gt 0 -or $neverRevealGroups.Count -eq 0) {
                    if ($neverRevealGroups.Count -eq 0) {
                        $issues += "No NeverRevealGroup configured (all accounts may be cacheable)"
                        $severity = "CRITICAL"
                    }

                    $allResults += [PSCustomObject]@{
                        CheckID                 = 'DC-040'
                        CheckName               = 'RODC Credential Caching Policy'
                        Domain                  = $domain.Name
                        ObjectDN                = $rodc.DistinguishedName
                        ObjectName              = $rodc.Name
                        FindingDetail           = "RODC credential caching policy issues: $($issues -join '; ')"
                        Severity                = $severity
                        NeverRevealGroupCount   = $neverRevealGroups.Count
                        RevealOnDemandCount     = $revealOnDemandGroups.Count
                        RevealedAccountsCount   = $revealedAccounts.Count
                        IssueCount              = $issues.Count
                        Timestamp               = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                        Engine                  = 'PowerShell'
                    }
                }
            }
        } catch {
            Write-Warning "Failed to query domain $($domain.Name): $_"
        }
    }

    if ($allResults.Count -gt 0) {
        Write-Host "`nFound $($allResults.Count) RODCs with credential caching policy issues across forest:" -ForegroundColor Yellow
        $allResults | Format-Table -AutoSize

        # Summary by severity and domain
        $criticalCount = ($allResults | Where-Object { $_.Severity -eq 'CRITICAL' }).Count
        $highCount = ($allResults | Where-Object { $_.Severity -eq 'HIGH' }).Count
        Write-Host "Critical: $criticalCount, High: $highCount" -ForegroundColor Yellow

        # Group by domain for summary
        $domainSummary = $allResults | Group-Object Domain | ForEach-Object {
            "$($_.Name): $($_.Count) RODCs"
        }
        Write-Host "Domain Summary: $($domainSummary -join ', ')" -ForegroundColor Cyan
    } else {
        Write-Host "`nNo findings - All RODCs have proper credential caching policies configured" -ForegroundColor Green
    }

    return $allResults

} catch {
    Write-Error "PowerShell AD query failed: $_"
    exit 1
}

# ── BloodHound Export ─────────────────────────────────────────────────────────
# Added by Kiro automation — DO NOT modify lines above this section
try {
    $bhSession = if ($env:ADSUITE_SESSION_ID) { $env:ADSUITE_SESSION_ID } else { [guid]::NewGuid().ToString('N') }
    $bhRoot    = if ($env:ADSUITE_OUTPUT_ROOT) { $env:ADSUITE_OUTPUT_ROOT } else { Join-Path $env:TEMP 'ADSuite_Sessions' }
    $bhDir     = Join-Path $bhRoot "$bhSession\bloodhound"
    if (-not (Test-Path $bhDir)) { New-Item -ItemType Directory -Path $bhDir -Force -ErrorAction Stop | Out-Null }

    $bhNodes = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($r in $output) {
        $dn   = if ($r.DistinguishedName) { $r.DistinguishedName } else { '' }
        $name = if ($r.Name) { $r.Name } else { 'UNKNOWN' }
        $dom  = (($dn -split ',') | Where-Object{$_ -match '^DC='} | ForEach-Object{$_ -replace '^DC=',''}) -join '.' | ForEach-Object{$_.ToUpper()}
        $oid  = if ($dn) { $dn.ToUpper() } else { [guid]::NewGuid().ToString() }

        $bhNodes.Add(@{
            ObjectIdentifier = $oid
            Properties       = @{
                name              = if ($dom) { "$($name.ToUpper())@$dom" } else { $name.ToUpper() }
                domain            = $dom
                distinguishedname = $dn.ToUpper()
                enabled           = $true
                adSuiteCheckId    = 'DC-040'
                adSuiteCheckName  = 'RODC_Credential_Caching_Policy'
                adSuiteMEDIUM   = 'MEDIUM'
                adSuiteDomain_Controllers   = 'Domain_Controllers'
                adSuiteFlag       = $true
            }
            Aces      = @()
            IsDeleted = $false
            IsACLProtected = $false
        })
    }

    $bhTs   = Get-Date -Format 'yyyyMMdd_HHmmss'
    $bhFile = Join-Path $bhDir "DC-040_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'domains'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────
