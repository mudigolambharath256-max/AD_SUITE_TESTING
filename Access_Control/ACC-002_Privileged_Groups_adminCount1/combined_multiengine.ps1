# ============================================================================
# ACC-002: Privileged Groups adminCount1
# ============================================================================
# Category: Access_Control
# Method: Multi-Engine (PowerShell + ADSI Fallback)
# Description: Attempts to use ActiveDirectory module, falls back to ADSI
#              if module is not available
# ============================================================================
# USAGE:
#   .\combined_multiengine.ps1
#
# FEATURES:
#   - Automatic detection of available methods
#   - Graceful fallback to ADSI if AD module unavailable
#   - Consistent output format regardless of method used
# ============================================================================

[CmdletBinding()]
param(
    [Parameter()]
    [string]$SearchBase,

    [Parameter()]
    [string]$ExportPath
)

Write-Host "=== ACC-002: Privileged Groups adminCount1 (Forest-Wide) ===" -ForegroundColor Cyan
Write-Host "Multi-Engine Security Check" -ForegroundColor Gray
Write-Host ""

# Try to import ActiveDirectory module
$useADModule = $false
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    $useADModule = $true
    Write-Host "[Method] Using ActiveDirectory PowerShell Module" -ForegroundColor Green
} catch {
    Write-Host "[Method] ActiveDirectory module not available, using ADSI" -ForegroundColor Yellow
}

$results = @()

if ($useADModule) {
    # ========================================================================
    # METHOD 1: PowerShell ActiveDirectory Module with Forest Enumeration
    # ========================================================================

    try {
        # Get all domains in the forest
        $forest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
        $allResults = @()

        foreach ($domain in $forest.Domains) {
            Write-Host "  Querying domain: $($domain.Name)" -ForegroundColor Cyan

            try {
                $domainDN = "DC=$($domain.Name.Replace('.', ',DC='))"
                $searchBase = if ($SearchBase) { $SearchBase } else { $domainDN }

                # Execute query for this domain
                $adObjects = Get-ADObject -Server $domain.Name `
                                           -LDAPFilter '(&(objectClass=group)(adminCount=1))' `
                                           -Properties name,distinguishedName,objectClass,whenCreated,whenChanged,adminCount `
                                           -SearchBase $searchBase `
                                           -SearchScope Subtree `
                                           -ResultSetSize $null `
                                           -ErrorAction Stop

                # Format results for this domain
                $domainResults = $adObjects | Select-Object `
                    @{N='CheckID'; E={'ACC-002'}}, `
                    @{N='CheckName'; E={'Privileged Groups adminCount1'}}, `
                    @{N='Domain'; E={$domain.Name}}, `
                    @{N='ObjectDN'; E={$_.distinguishedName}}, `
                    @{N='ObjectName'; E={$_.name}}, `
                    @{N='FindingDetail'; E={"Privileged group with adminCount=1: ObjectClass=$($_.objectClass), Created=$($_.whenCreated)"}}, `
                    @{N='Severity'; E={'HIGH'}}, `
                    @{N='Timestamp'; E={(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')}}, `
                    @{N='Engine'; E={'PowerShell'}}

                $allResults += $domainResults
            } catch {
                Write-Warning "Failed to query domain $($domain.Name): $_"
            }
        }

        $results = $allResults
        Write-Host "Found $($results.Count) privileged groups across forest using PowerShell method" -ForegroundColor Green

    } catch {
        Write-Error "PowerShell method failed: $_"
        $useADModule = $false
    }
}

if (-not $useADModule) {
    # ========================================================================
    # METHOD 2: ADSI with Forest Enumeration
    # ========================================================================

    try {
        # Get all domains in the forest
        $forest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
        $allResults = @()

        foreach ($domain in $forest.Domains) {
            Write-Host "  Querying domain: $($domain.Name)" -ForegroundColor Cyan

            try {
                $domainNC = "DC=$($domain.Name.Replace('.', ',DC='))"

                # Create searcher for this domain
                $searcher = New-Object System.DirectoryServices.DirectorySearcher
                $searcher.SearchRoot = [ADSI]"LDAP://$($domain.Name)/$domainNC"
                $searcher.Filter = '(&(objectClass=group)(adminCount=1))'
                $searcher.PageSize = 1000
                $searcher.PropertiesToLoad.Clear()
                (@('name', 'distinguishedName', 'objectClass', 'whenCreated', 'whenChanged', 'adminCount') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) })

                # Execute search for this domain
                $adsiResults = $searcher.FindAll()

                # Format results for this domain
                $domainResults = $adsiResults | ForEach-Object {
                    $props = $_.Properties
                    [PSCustomObject]@{
                        CheckID           = 'ACC-002'
                        CheckName         = 'Privileged Groups adminCount1'
                        Domain            = $domain.Name
                        ObjectDN          = if ($props['distinguishedname'].Count -gt 0) { $props['distinguishedname'][0] } else { 'N/A' }
                        ObjectName        = if ($props['name'].Count -gt 0) { $props['name'][0] } else { 'N/A' }
                        FindingDetail     = "Privileged group with adminCount=1: ObjectClass=$($props['objectclass'][0]), Created=$($props['whencreated'][0])"
                        Severity          = 'HIGH'
                        Timestamp         = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                        Engine            = 'ADSI'
                    }
                }

                $allResults += $domainResults

                # Cleanup
                $searcher.Dispose()
            } catch {
                Write-Warning "Failed to query domain $($domain.Name): $_"
            }
        }

        $results = $allResults
        Write-Host "Found $($results.Count) privileged groups across forest using ADSI method" -ForegroundColor Green

    } catch {
        Write-Error "ADSI method failed: $_"
        exit 1
    }
}

# Display and export results
if ($results.Count -gt 0) {
    Write-Host "`n=== Results ===" -ForegroundColor Yellow
    $results | Format-List

    # Summary by severity and domain
    $criticalCount = ($results | Where-Object { $_.Severity -eq 'CRITICAL' }).Count
    $highCount = ($results | Where-Object { $_.Severity -eq 'HIGH' }).Count
    Write-Host "Critical: $criticalCount, High: $highCount" -ForegroundColor Yellow

    # Group by domain for summary
    $domainSummary = $results | Group-Object Domain | ForEach-Object {
        "$($_.Name): $($_.Count) groups"
    }
    Write-Host "Domain Summary: $($domainSummary -join ', ')" -ForegroundColor Cyan

} else {
    Write-Host "`nNo privileged groups found" -ForegroundColor Green
}

return $results


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
                adSuiteCheckId    = 'ACC-002'
                adSuiteCheckName  = 'Privileged_Groups_adminCount1'
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
    $bhFile = Join-Path $bhDir "ACC-002_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'users'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────
