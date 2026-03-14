# ============================================================================
# TMGMT-003: Orphaned Foreign Security Principals
# ============================================================================
# Category: Trust_Management
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

Write-Host "=== TMGMT-003: Orphaned Foreign Security Principals ===" -ForegroundColor Cyan
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
    # METHOD 1: PowerShell ActiveDirectory Module
    # ========================================================================

    try {
        $domain = Get-ADDomain -ErrorAction Stop
        $domainDN = $domain.DistinguishedName
        $domainName = $domain.DNSRoot

        if (-not $SearchBase) { $SearchBase = $domainDN }

        Write-Host "Domain: $domainName" -ForegroundColor Cyan
        Write-Host "Search Base: $SearchBase" -ForegroundColor Gray
        Write-Host ""

        # Execute query
        $adObjects = Get-ADObject -LDAPFilter '(objectClass=foreignSecurityPrincipal)' `
                                   -Properties name,distinguishedName,objectClass,whenCreated,whenChanged `
                                   -SearchBase $SearchBase `
                                   -SearchScope Subtree `
                                   -ResultSetSize $null `
                                   -ErrorAction Stop

        # Format results
        $results = $adObjects | Select-Object `
            @{N='CheckID'; E={'TMGMT-003'}}, `
            @{N='CheckName'; E={'Orphaned Foreign Security Principals'}}, `
            @{N='Method'; E={'PowerShell'}}, `
            @{N='Domain'; E={$domainName}}, `
            name, distinguishedName, objectClass, whenCreated, whenChanged

        Write-Host "Found $($results.Count) objects using PowerShell method" -ForegroundColor Green

    } catch {
        Write-Error "PowerShell method failed: $_"
        $useADModule = $false
    }
}

if (-not $useADModule) {
    # ========================================================================
    # METHOD 2: ADSI (Active Directory Service Interfaces)
    # ========================================================================

    try {
        # Initialize LDAP connection
        $root = [ADSI]'LDAP://RootDSE'
        $domainNC = $root.defaultNamingContext.ToString()

        Write-Host "Domain NC: $domainNC" -ForegroundColor Cyan
        Write-Host ""

        # Create searcher
        $searcher = New-Object System.DirectoryServices.DirectorySearcher
        $searcher.SearchRoot = [ADSI]"LDAP://$domainNC"
        $searcher.Filter = '(objectClass=foreignSecurityPrincipal)'
        $searcher.PageSize = 1000
        $searcher.PropertiesToLoad.Clear()
        @('name', 'distinguishedName', 'objectClass', 'whenCreated', 'whenChanged', 'objectSid') |
            ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }

        # Execute search
        $adsiResults = $searcher.FindAll()

        # Format results
        $results = $adsiResults | ForEach-Object {
            $props = $_.Properties
            [PSCustomObject]@{
                CheckID           = 'TMGMT-003'
                CheckName         = 'Orphaned Foreign Security Principals'
                Method            = 'ADSI'
                Domain            = $domainNC
                Name              = if ($props['name'].Count -gt 0) { $props['name'][0] } else { 'N/A' }
                DistinguishedName = if ($props['distinguishedname'].Count -gt 0) { $props['distinguishedname'][0] } else { 'N/A' }
                ObjectClass       = if ($props['objectclass'].Count -gt 0) { $props['objectclass'][0] } else { 'N/A' }
                WhenCreated       = if ($props['whencreated'].Count -gt 0) { $props['whencreated'][0] } else { 'N/A' }
                WhenChanged       = if ($props['whenchanged'].Count -gt 0) { $props['whenchanged'][0] } else { 'N/A' }
            }
        }

        Write-Host "Found $($results.Count) objects using ADSI method" -ForegroundColor Green

        # Cleanup
        $searcher.Dispose()

    } catch {
        Write-Error "ADSI method failed: $_"
        exit 1
    }
}

# Display and export results
if ($results.Count -gt 0) {
    Write-Host "`n=== Results ===" -ForegroundColor Yellow
    $results | Format-List

} else {
    Write-Host "`nNo objects found" -ForegroundColor Gray
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
                adSuiteCheckId    = 'TMGMT-003'
                adSuiteCheckName  = 'Orphaned_Foreign_Security_Principals'
                adSuiteMEDIUM   = 'MEDIUM'
                adSuiteTrust_Management   = 'Trust_Management'
                adSuiteFlag       = $true
            }
            Aces      = @()
            IsDeleted = $false
            IsACLProtected = $false
        })
    }

    $bhTs   = Get-Date -Format 'yyyyMMdd_HHmmss'
    $bhFile = Join-Path $bhDir "TMGMT-003_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'domains'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────
