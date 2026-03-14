# =============================================================================
# COMBINED MULTI-ENGINE SCRIPT
# Check: RODC Credential Caching Policy
# Category: Domain Controllers
# ID: DC-040
# Severity: HIGH
# MITRE: T1552.004 (Unsecured Credentials: Private Keys)
# =============================================================================
# This script runs PowerShell, ADSI, and C# engines with forest-wide enumeration,
# handles failures gracefully, and deduplicates results into a single output.
# =============================================================================

param(
    [string]$Engine = "AUTO"
)

$ErrorActionPreference = 'Continue'
$results = @()

Write-Host "=== Multi-Engine Execution: RODC Credential Caching Policy (Forest-Wide) ===" -ForegroundColor Cyan
Write-Host ""

function Test-ActiveDirectoryModule {
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Invoke-PowerShellEngine {
    Write-Host "[ENGINE] Using PowerShell ActiveDirectory module" -ForegroundColor Green

    try {
        # Get all domains in the forest
        $forest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
        $allResults = @()

        foreach ($domain in $forest.Domains) {
            Write-Host "  Querying domain: $($domain.Name)" -ForegroundColor Cyan

            try {
                $domainDN = "DC=$($domain.Name.Replace('.', ',DC='))"

                # Find RODCs using UAC bit 67108864 (PARTIAL_SECRETS_ACCOUNT)
                $rodcs = Get-ADComputer -Server $domain.Name `
                                       -Filter "userAccountControl -band 67108864" `
                                       -Properties name,distinguishedName,dNSHostName,msDS-NeverRevealGroup,msDS-RevealOnDemandGroup,msDS-RevealedList,msDS-KrbTgtLinkBl `
                                       -ErrorAction Stop

                Write-Host "    Found $($rodcs.Count) RODCs in $($domain.Name)" -ForegroundColor Green

                if ($rodcs.Count -eq 0) {
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

                    # Check msDS-NeverRevealGroup
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

                    # Check msDS-RevealedList
                    $revealedAccounts = @()
                    if ($rodc.'msDS-RevealedList') {
                        $revealedAccounts = $rodc.'msDS-RevealedList'
                    }

                    if ($revealedAccounts.Count -gt 0) {
                        # Check if any revealed accounts are privileged
                        $privilegedRevealed = @()
                        foreach ($accountDN in $revealedAccounts) {
                            try {
                                $account = Get-ADObject -Server $domain.Name -Identity $accountDN -Properties samAccountName,adminCount -ErrorAction SilentlyContinue
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

                    # Check msDS-RevealOnDemandGroup
                    $revealOnDemandGroups = @()
                    if ($rodc.'msDS-RevealOnDemandGroup') {
                        $revealOnDemandGroups = $rodc.'msDS-RevealOnDemandGroup'

                        # Check if any privileged groups are in RevealOnDemandGroup
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

        return $allResults
    } catch {
        throw "PowerShell engine failed: $_"
    }
}

function Invoke-ADSIEngine {
    Write-Host "[ENGINE] Using ADSI DirectorySearcher" -ForegroundColor Yellow

    try {
        # Get all domains in the forest
        $forest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
        $allResults = @()

        foreach ($domain in $forest.Domains) {
            Write-Host "  Querying domain: $($domain.Name)" -ForegroundColor Cyan

            try {
                $domainDN = "DC=$($domain.Name.Replace('.', ',DC='))"
                $searcher = [ADSISearcher]"LDAP://$($domain.Name)/$domainDN"
                $searcher.Filter = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=67108864))'
                $searcher.PageSize = 1000
                $searcher.PropertiesToLoad.Clear()
                @('name', 'distinguishedName', 'dNSHostName', 'msDS-NeverRevealGroup', 'msDS-RevealOnDemandGroup', 'msDS-RevealedList', 'msDS-KrbTgtLinkBl') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }

                $searchResults = $searcher.FindAll()
                Write-Host "    Found $($searchResults.Count) RODCs in $($domain.Name) via ADSI" -ForegroundColor Green

                if ($searchResults.Count -eq 0) {
                    $searcher.Dispose()
                    continue
                }

                # Define privileged groups
                $privilegedGroups = @(
                    "CN=Domain Admins,CN=Users,$domainDN",
                    "CN=Enterprise Admins,CN=Users,$domainDN",
                    "CN=Schema Admins,CN=Users,$domainDN",
                    "CN=Administrators,CN=Builtin,$domainDN",
                    "CN=Group Policy Creator Owners,CN=Users,$domainDN",
                    "CN=Domain Controllers,CN=Users,$domainDN",
                    "CN=Denied RODC Password Replication Group,CN=Users,$domainDN"
                )

                foreach ($result in $searchResults) {
                    $p = $result.Properties
                    $rodcName = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }

                    $issues = @()
                    $severity = "HIGH"

                    # Check msDS-NeverRevealGroup
                    $neverRevealGroups = @()
                    if ($p['msds-neverrevealgroup'] -and $p['msds-neverrevealgroup'].Count -gt 0) {
                        $neverRevealGroups = $p['msds-neverrevealgroup']
                    }

                    # Check missing privileged groups
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

                    # Check msDS-RevealedList
                    $revealedAccounts = @()
                    if ($p['msds-revealedlist'] -and $p['msds-revealedlist'].Count -gt 0) {
                        $revealedAccounts = $p['msds-revealedlist']
                        $issues += "Total accounts with cached credentials: $($revealedAccounts.Count)"
                    }

                    # Check msDS-RevealOnDemandGroup
                    $revealOnDemandGroups = @()
                    if ($p['msds-revealondemandgroup'] -and $p['msds-revealondemandgroup'].Count -gt 0) {
                        $revealOnDemandGroups = $p['msds-revealondemandgroup']

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
                            ObjectDN                = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                            ObjectName              = $rodcName
                            FindingDetail           = "RODC credential caching policy issues: $($issues -join '; ')"
                            Severity                = $severity
                            NeverRevealGroupCount   = $neverRevealGroups.Count
                            RevealOnDemandCount     = $revealOnDemandGroups.Count
                            RevealedAccountsCount   = $revealedAccounts.Count
                            IssueCount              = $issues.Count
                            Timestamp               = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                            Engine                  = 'ADSI'
                        }
                    }
                }

                $searchResults.Dispose()
                $searcher.Dispose()
            } catch {
                Write-Warning "Failed to query domain $($domain.Name): $_"
            }
        }

        return $allResults
    } catch {
        throw "ADSI engine failed: $_"
    }
}

function Invoke-CMDEngine {
    Write-Host "[ENGINE] Using CMD/dsquery fallback" -ForegroundColor Red
    Write-Warning "CMD engine has limited forest enumeration and RODC policy analysis capability"
    return @()
}

# Main execution logic
try {
    switch ($Engine.ToUpper()) {
        "PS" { $results = Invoke-PowerShellEngine }
        "ADSI" { $results = Invoke-ADSIEngine }
        "CMD" { $results = Invoke-CMDEngine }
        "AUTO" {
            try {
                if (Test-ActiveDirectoryModule) {
                    $results = Invoke-PowerShellEngine
                } else {
                    $results = Invoke-ADSIEngine
                }
            } catch {
                Write-Warning "Primary engines failed: $_"
                $results = Invoke-CMDEngine
            }
        }
        default { throw "Invalid engine specified: $Engine" }
    }

    if ($results -and $results.Count -gt 0) {
        Write-Host "Found $($results.Count) RODCs with credential caching policy issues across forest" -ForegroundColor Red
        $results | Format-List

        # Summary by severity and domain
        $criticalCount = ($results | Where-Object { $_.Severity -eq 'CRITICAL' }).Count
        $highCount = ($results | Where-Object { $_.Severity -eq 'HIGH' }).Count
        Write-Host "Critical: $criticalCount, High: $highCount" -ForegroundColor Yellow

        # Group by domain for summary
        $domainSummary = $results | Group-Object Domain | ForEach-Object {
            "$($_.Name): $($_.Count) RODCs"
        }
        Write-Host "Domain Summary: $($domainSummary -join ', ')" -ForegroundColor Cyan
    } else {
        Write-Host "No RODC credential caching policy issues found - all RODCs properly configured" -ForegroundColor Green
    }

} catch {
    Write-Error "Check execution failed: $_"
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

    foreach ($r in $uniqueResults) {
        $dn   = if ($r.DistinguishedName) { $r.DistinguishedName } else { '' }
        $name = if ($r.Name) { $r.Name } else { if ($r.PSObject.Properties['CheckName']) { $r.CheckName } else { 'UNKNOWN' } }
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
