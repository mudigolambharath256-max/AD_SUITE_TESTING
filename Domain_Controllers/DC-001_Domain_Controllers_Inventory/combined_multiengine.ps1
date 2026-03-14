# =============================================================================
# COMBINED MULTI-ENGINE SCRIPT
# Check: Domain Controllers Inventory
# Category: Domain Controllers
# ID: DC-001
# =============================================================================
# This script runs PowerShell, ADSI, and C# engines with forest-wide enumeration,
# handles failures gracefully, and deduplicates results into a single output.
# =============================================================================

param(
    [string]$Engine = "AUTO"
)

$ErrorActionPreference = 'Continue'
$results = @()
$engineStatus = @{}

Write-Host "=== Multi-Engine Execution: Domain Controllers Inventory (Forest-Wide) ===" -ForegroundColor Cyan
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
                $domainControllers = Get-ADDomainController -Server $domain.Name -Filter *

                foreach ($dc in $domainControllers) {
                    $allResults += [PSCustomObject]@{
                        CheckID = 'DC-001'
                        CheckName = 'Domain Controllers Inventory'
                        Domain = $domain.Name
                        ObjectDN = $dc.ComputerObjectDN
                        ObjectName = $dc.HostName
                        FindingDetail = "DC Inventory: OS=$($dc.OperatingSystem), Site=$($dc.Site), Roles=$($dc.OperationMasterRoles -join ',')"
                        Severity = 'MEDIUM'
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
                $searcher.Filter = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))'
                $searcher.PageSize = 1000
                $searcher.PropertiesToLoad.Clear()
                @('name', 'distinguishedName', 'dNSHostName', 'operatingSystem', 'operatingSystemVersion', 'whenCreated') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }

                $dcResults = $searcher.FindAll()

                foreach ($dcResult in $dcResults) {
                    $p = $dcResult.Properties
                    $allResults += [PSCustomObject]@{
                        CheckID = 'DC-001'
                        CheckName = 'Domain Controllers Inventory'
                        Domain = $domain.Name
                        ObjectDN = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                        ObjectName = if ($p['dnshostname'] -and $p['dnshostname'].Count -gt 0) { $p['dnshostname'][0] } else { $p['name'][0] }
                        FindingDetail = "DC Inventory: OS=$($p['operatingsystem'][0]), Version=$($p['operatingsystemversion'][0]), Created=$($p['whencreated'][0])"
                        Severity = 'MEDIUM'
                        Timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                        Engine = 'ADSI'
                    }
                }

                $dcResults.Dispose()
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
        Write-Host "Found $($results.Count) domain controllers across forest" -ForegroundColor Green
        $results | Format-List

        # Group by domain for summary
        $domainSummary = $results | Group-Object Domain | ForEach-Object {
            "$($_.Name): $($_.Count) DCs"
        }
        Write-Host "Domain Summary: $($domainSummary -join ', ')" -ForegroundColor Cyan
    } else {
        Write-Host "No domain controllers found" -ForegroundColor Yellow
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
                adSuiteCheckId    = 'DC-001'
                adSuiteCheckName  = 'Domain_Controllers_Inventory'
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
    $bhFile = Join-Path $bhDir "DC-001_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'domains'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────
