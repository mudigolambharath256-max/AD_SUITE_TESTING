# ============================================================================
# CMGMT-037: LAPS Read Permissions Audit
# ============================================================================
# Category: Computer_Management
# Method: PowerShell ActiveDirectory Module
# Severity: MEDIUM
# MITRE: T1003.002
# ============================================================================

[CmdletBinding()]
param(
    [Parameter()][string]$SearchBase,
    [Parameter()][string]$ExportPath
)

Import-Module ActiveDirectory -ErrorAction Stop

$domain = Get-ADDomain
$domainDN = $domain.DistinguishedName
if (-not $SearchBase) { $SearchBase = $domainDN }

Write-Host "Executing: LAPS Read Permissions Audit" -ForegroundColor Cyan
Write-Host "Check ID: CMGMT-037" -ForegroundColor Gray

$results = Get-ADObject -LDAPFilter '(&(objectCategory=computer)(ms-Mcs-AdmPwd=*))' `
                        -Properties name,distinguishedName,whenCreated,whenChanged ,objectSid `
                        -SearchBase $SearchBase `
                        -SearchScope Subtree `
                        -ResultSetSize $null

Write-Host "Found $($results.Count) objects" -ForegroundColor Cyan

$output = $results | Select-Object `
    @{N='CheckID'; E={'CMGMT-037'}}, `
    @{N='CheckName'; E={'LAPS Read Permissions Audit'}}, `
    @{N='RiskScore'; E={6}}, `
    @{N='Severity'; E={'MEDIUM'}}, `
    @{N='MITRE'; E={'T1003.002'}}, `
    name, distinguishedName, whenCreated, whenChanged

if ($output.Count -gt 0) {
    $output | Format-Table -AutoSize

}

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
                adSuiteCheckId    = 'CMGMT-037'
                adSuiteCheckName  = 'LAPS_Read_Permissions_Audit'
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
    $bhFile = Join-Path $bhDir "CMGMT-037_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'computers'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────
