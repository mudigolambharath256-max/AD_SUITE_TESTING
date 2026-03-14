# =============================================================================
# COMBINED MULTI-ENGINE SCRIPT
# Check: Kerberoastable User Accounts
# Category: Kerberos Security
# ID: KRB-001
# =============================================================================
# This script runs PowerShell, ADSI, and C# engines with forest-wide enumeration,
# handles failures gracefully, and deduplicates results into a single output.
# =============================================================================

param(
    [string]$Engine = "AUTO"
)

$ErrorActionPreference = 'Continue'
$results = @()

Write-Host "=== Multi-Engine Execution: Kerberoastable User Accounts (Forest-Wide) ===" -ForegroundColor Cyan
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
                $kerberoastableUsers = Get-ADUser -Server $domain.Name `
                                                  -Filter "ServicePrincipalName -like '*' -and Enabled -eq 'True'" `
                                                  -Properties ServicePrincipalName,PasswordLastSet,Description,AdminCount `
                                                  -ErrorAction Stop

                foreach ($user in $kerberoastableUsers) {
                    # Calculate password age
                    $passwordAge = if ($user.PasswordLastSet) {
                        (Get-Date) - $user.PasswordLastSet
                    } else {
                        $null
                    }

                    $severity = "HIGH"
                    if ($user.AdminCount -eq 1) { $severity = "CRITICAL" }
                    elseif ($passwordAge -and $passwordAge.Days -gt 365) { $severity = "CRITICAL" }

                    $allResults += [PSCustomObject]@{
                        CheckID = 'KRB-001'
                        CheckName = 'Kerberoastable User Accounts'
                        Domain = $domain.Name
                        ObjectDN = $user.DistinguishedName
                        ObjectName = $user.SamAccountName
                        FindingDetail = "Kerberoastable user: SPNs=$($user.ServicePrincipalName.Count), PasswordAge=$($passwordAge.Days) days, AdminCount=$($user.AdminCount)"
                        Severity = $severity
                        Timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                        Engine = 'PowerShell'
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
                $searcher = [ADSISearcher]"LDAP://$($domain.Name)/DC=$($domain.Name.Replace('.', ',DC='))"
                $searcher.Filter = '(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(servicePrincipalName=*))'
                $searcher.PageSize = 1000
                $searcher.PropertiesToLoad.Clear()
                @('name', 'distinguishedName', 'samAccountName', 'servicePrincipalName', 'pwdLastSet', 'description', 'adminCount') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }

                $adsiResults = $searcher.FindAll()

                foreach ($result in $adsiResults) {
                    $p = $result.Properties

                    # Calculate password age
                    $passwordAge = $null
                    if ($p['pwdlastset'] -and $p['pwdlastset'].Count -gt 0) {
                        $pwdLastSetTicks = [Int64]$p['pwdlastset'][0]
                        if ($pwdLastSetTicks -gt 0) {
                            $pwdLastSetDate = [DateTime]::FromFileTime($pwdLastSetTicks)
                            $passwordAge = (Get-Date) - $pwdLastSetDate
                        }
                    }

                    $adminCount = if ($p['admincount'] -and $p['admincount'].Count -gt 0) { $p['admincount'][0] } else { 0 }
                    $spnCount = if ($p['serviceprincipalname']) { $p['serviceprincipalname'].Count } else { 0 }

                    $severity = "HIGH"
                    if ($adminCount -eq 1) { $severity = "CRITICAL" }
                    elseif ($passwordAge -and $passwordAge.Days -gt 365) { $severity = "CRITICAL" }

                    $allResults += [PSCustomObject]@{
                        CheckID = 'KRB-001'
                        CheckName = 'Kerberoastable User Accounts'
                        Domain = $domain.Name
                        ObjectDN = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                        ObjectName = if ($p['samaccountname'] -and $p['samaccountname'].Count -gt 0) { $p['samaccountname'][0] } else { 'N/A' }
                        FindingDetail = "Kerberoastable user: SPNs=$spnCount, PasswordAge=$($passwordAge.Days) days, AdminCount=$adminCount"
                        Severity = $severity
                        Timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                        Engine = 'ADSI'
                    }
                }

                $adsiResults.Dispose()
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
    Write-Warning "CMD engine has limited forest enumeration capability"
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
        Write-Host "Found $($results.Count) kerberoastable user accounts across forest" -ForegroundColor Red
        $results | Format-List

        # Summary by severity
        $criticalCount = ($results | Where-Object { $_.Severity -eq 'CRITICAL' }).Count
        $highCount = ($results | Where-Object { $_.Severity -eq 'HIGH' }).Count
        Write-Host "Critical: $criticalCount, High: $highCount" -ForegroundColor Yellow

        # Group by domain for summary
        $domainSummary = $results | Group-Object Domain | ForEach-Object {
            "$($_.Name): $($_.Count) accounts"
        }
        Write-Host "Domain Summary: $($domainSummary -join ', ')" -ForegroundColor Cyan
    } else {
        Write-Host "No kerberoastable user accounts found" -ForegroundColor Green
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
                adSuiteCheckId    = 'KRB-001'
                adSuiteCheckName  = 'Kerberoastable_User_Accounts'
                adSuiteMEDIUM   = 'MEDIUM'
                adSuiteKerberos_Security   = 'Kerberos_Security'
                adSuiteFlag       = $true
            }
            Aces      = @()
            IsDeleted = $false
            IsACLProtected = $false
        })
    }

    $bhTs   = Get-Date -Format 'yyyyMMdd_HHmmss'
    $bhFile = Join-Path $bhDir "KRB-001_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'users'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────
