# ============================================================================
# CMGMT-009: Computers with Unconstrained Delegation
# ============================================================================
# Category: Computer_Management
# Method: PowerShell ActiveDirectory Module
# Description: Uses Get-ADObject cmdlet for querying Active Directory
# Requirements: ActiveDirectory PowerShell module must be installed
# ============================================================================
# USAGE:
#   .\powershell.ps1
#
# PARAMETERS:
#   -SearchBase <String>  : Optional OU to limit search scope
#   -ExportPath <String>  : Optional CSV export path
#
# OUTPUT:
#   Returns AD objects matching the security check criteria
# ============================================================================

[CmdletBinding()]
param(
    [Parameter()]
    [string]$SearchBase,

    [Parameter()]
    [string]$ExportPath
)

# Import ActiveDirectory module
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Host "ActiveDirectory module loaded successfully" -ForegroundColor Green
} catch {
    Write-Error "Failed to load ActiveDirectory module: $_"
    exit 1
}

# Get domain information
try {
    $domain = Get-ADDomain -ErrorAction Stop
    $domainDN = $domain.DistinguishedName
    $domainName = $domain.DNSRoot

    Write-Host "Connected to domain: $domainName" -ForegroundColor Cyan
} catch {
    Write-Error "Failed to connect to domain: $_"
    exit 1
}

# Set search base if not provided
if (-not $SearchBase) {
    $SearchBase = $domainDN
    Write-Host "Using default search base: $SearchBase" -ForegroundColor Gray
}

# Define LDAP filter for the check
$ldapFilter = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=524288))'

# Define properties to retrieve
$properties = @('name', 'distinguishedName', 'objectClass', 'whenCreated', 'whenChanged', 'objectSid')

Write-Host "Executing security check: Computers with Unconstrained Delegation" -ForegroundColor Yellow
Write-Host "Check ID: CMGMT-009" -ForegroundColor Gray

# Execute AD query
try {
    $results = Get-ADObject -LDAPFilter $ldapFilter `
                            -Properties $properties `
                            -SearchBase $SearchBase `
                            -SearchScope Subtree `
                            -ResultSetSize $null `
                            -ErrorAction Stop

    Write-Host "Found $($results.Count) objects" -ForegroundColor Cyan
} catch {
    Write-Error "Query failed: $_"
    exit 1
}

# Process and format results
$output = $results | Select-Object `
    @{N='CheckID'; E={'CMGMT-009'}}, `
    @{N='CheckName'; E={'Computers with Unconstrained Delegation'}}, `
    @{N='Domain'; E={$domainName}}, `
    name, `
    distinguishedName, `
    objectClass, `
    whenCreated, `
    whenChanged

# Display results
if ($output.Count -gt 0) {
    Write-Host "`n=== Results ===" -ForegroundColor Yellow
    $output | Format-Table -AutoSize

    # Export if path provided

} else {
    Write-Host "`nNo objects found matching criteria" -ForegroundColor Gray
}

# Return results
return $output



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
                adSuiteCheckId    = 'CMGMT-009'
                adSuiteCheckName  = 'Computers_with_Unconstrained_Delegation'
                adSuiteMEDIUM   = 'MEDIUM'
                adSuiteComputer_Management   = 'Computer_Management'
                adSuiteFlag       = $true
            }
            Aces      = @()
            IsDeleted = $false
            IsACLProtected = $false
        })
    }

    $bhTs   = Get-Date -Format 'yyyyMMdd_HHmmss'
    $bhFile = Join-Path $bhDir "CMGMT-009_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'computers'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────
