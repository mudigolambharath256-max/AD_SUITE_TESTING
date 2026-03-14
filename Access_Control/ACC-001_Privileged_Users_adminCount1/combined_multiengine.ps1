# ============================================================================
# ACC-001: Privileged Users adminCount1
# ============================================================================
# Category: Access_Control
# Method: Multi-Engine (PowerShell + ADSI Fallback) with Forest-Wide Enumeration
# Description: Attempts to use ActiveDirectory module, falls back to ADSI
#              if module is not available. Enumerates all domains in forest.
# ============================================================================

param(
    [string]$Engine = "AUTO"
)

$ErrorActionPreference = 'Continue'
$results = @()

Write-Host "=== Multi-Engine Execution: Privileged Users adminCount1 (Forest-Wide) ===" -ForegroundColor Cyan
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
                $adObjects = Get-ADObject -Server $domain.Name `
                                         -LDAPFilter '(&(objectCategory=person)(objectClass=user)(adminCount=1)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))' `
                                         -Properties name,distinguishedName,samAccountName,adminCount,userAccountControl,whenCreated,whenChanged `
                                         -ErrorAction Stop

                foreach ($obj in $adObjects) {
                    $allResults += [PSCustomObject]@{
                        CheckID = 'ACC-001'
                        CheckName = 'Privileged Users adminCount1'
                        Domain = $domain.Name
                        ObjectDN = $obj.DistinguishedName
                        ObjectName = $obj.samAccountName
                        FindingDetail = "Privileged user with adminCount=1: UAC=$($obj.userAccountControl), Created=$($obj.whenCreated)"
                        Severity = 'HIGH'
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
                $searcher.Filter = '(&(objectCategory=person)(objectClass=user)(adminCount=1)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))'
                $searcher.PageSize = 1000
                $searcher.PropertiesToLoad.Clear()
                @('name', 'distinguishedName', 'samAccountName', 'adminCount', 'userAccountControl', 'whenCreated', 'whenChanged') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }

                $adsiResults = $searcher.FindAll()

                foreach ($result in $adsiResults) {
                    $p = $result.Properties
                    $allResults += [PSCustomObject]@{
                        CheckID = 'ACC-001'
                        CheckName = 'Privileged Users adminCount1'
                        Domain = $domain.Name
                        ObjectDN = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                        ObjectName = if ($p['samaccountname'] -and $p['samaccountname'].Count -gt 0) { $p['samaccountname'][0] } else { 'N/A' }
                        FindingDetail = "Privileged user with adminCount=1: UAC=$($p['useraccountcontrol'][0]), Created=$($p['whencreated'][0])"
                        Severity = 'HIGH'
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
        Write-Host "Found $($results.Count) privileged users with adminCount=1 across forest" -ForegroundColor Yellow
        $results | Format-List

        # Group by domain for summary
        $domainSummary = $results | Group-Object Domain | ForEach-Object {
            "$($_.Name): $($_.Count) users"
        }
        Write-Host "Domain Summary: $($domainSummary -join ', ')" -ForegroundColor Cyan
    } else {
        Write-Host "No privileged users with adminCount=1 found" -ForegroundColor Green
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
                adSuiteCheckId    = 'ACC-001'
                adSuiteCheckName  = 'Privileged_Users_adminCount1'
                adSuiteMEDIUM   = 'MEDIUM'
                adSuiteAccess_Control   = 'Access_Control'
                adSuiteFlag       = $true
            }
            Aces      = @()
            IsDeleted = $false
            IsACLProtected = $false
        })
    }

    $bhTs   = Get-Date -Format 'yyyyMMdd_HHmmss'
    $bhFile = Join-Path $bhDir "ACC-001_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'users'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────
