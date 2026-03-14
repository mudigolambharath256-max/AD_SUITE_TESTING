# ============================================================================
# NET-001: IPsec Policy Validation
# ============================================================================
# Version: 3.0.0
# Category: Network_Security
# Method: PowerShell ActiveDirectory Module
# Severity: MEDIUM
# MITRE: T1040
# ============================================================================

# ============================================================================
# DETECTION LIMITATION:
#   DetectionConfidence: Low
#   DataSource: LDAP (directory approximation only)
#   FalsePositiveRisk: High
#
#   This check returns a list of candidate computers from AD.
#   It CANNOT determine IPsec policy enforcement (requires checking RSVP service and IPsec policy objects) via LDAP alone.
#   Host-level validation requires WMI, registry, or network scanning.
#   Results should be treated as a SCOPE LIST for further manual validation.
#   Do NOT treat all returned hosts as confirmed findings.
# ============================================================================

[CmdletBinding()]
param(
    [Parameter()][string]$SearchBase,
    [Parameter()][string]$ExportPath
)

try {
    Import-Module ActiveDirectory -ErrorAction Stop
} catch {
    Write-Host "ERROR: ActiveDirectory module not available" -ForegroundColor Red
    Write-Host "Install RSAT tools or use adsi.ps1" -ForegroundColor Yellow
    exit 1
}

$domain = Get-ADDomain
$domainDN = $domain.DistinguishedName
if (-not $SearchBase) { $SearchBase = $domainDN }

Write-Host "[NET-001] IPsec Policy Validation" -ForegroundColor Cyan
Write-Host "Severity: MEDIUM | Risk: 6/10 | MITRE: T1040" -ForegroundColor Gray

$results = Get-ADObject -LDAPFilter '(objectClass=ipsecPolicy)' `
                        -Properties name,distinguishedName,whenCreated,whenChanged ,objectSid `
                        -SearchBase $SearchBase `
                        -SearchScope Subtree `
                        -ResultSetSize $null `
                        -ErrorAction SilentlyContinue

Write-Host "Found $($results.Count) objects" -ForegroundColor $(if ($results.Count -gt 0) { 'Yellow' } else { 'Green' })

$output = $results | Select-Object `
    @{N='CheckID'; E={'NET-001'}}, `
    @{N='CheckName'; E={'IPsec Policy Validation'}}, `
    @{N='RiskScore'; E={6}}, `
    @{N='Severity'; E={'MEDIUM'}}, `
    @{N='MITRE'; E={'T1040'}}, `
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
                adSuiteCheckId    = 'NET-001'
                adSuiteCheckName  = 'IPsec_Policy_Validation'
                adSuiteMEDIUM   = 'MEDIUM'
                adSuiteNetwork_Security   = 'Network_Security'
                adSuiteFlag       = $true
            }
            Aces      = @()
            IsDeleted = $false
            IsACLProtected = $false
        })
    }

    $bhTs   = Get-Date -Format 'yyyyMMdd_HHmmss'
    $bhFile = Join-Path $bhDir "NET-001_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'domains'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────
