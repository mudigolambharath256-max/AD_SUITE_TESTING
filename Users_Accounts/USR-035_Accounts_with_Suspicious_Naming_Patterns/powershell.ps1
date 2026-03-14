# ============================================================================
# USR-035: Accounts with Suspicious Naming Patterns
# ============================================================================
# Category: Users_and_Accounts
# Method: PowerShell ActiveDirectory Module
# Severity: MEDIUM
# MITRE: T1136.002
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

Write-Host "Executing: Accounts with Suspicious Naming Patterns" -ForegroundColor Cyan
Write-Host "Check ID: USR-035" -ForegroundColor Gray

$results = Get-ADObject -LDAPFilter '(&(objectCategory=person)(objectClass=user))' `
                        -Properties name,distinguishedName,whenCreated,whenChanged ,objectSid `
                        -SearchBase $SearchBase `
                        -SearchScope Subtree `
                        -ResultSetSize $null

Write-Host "Found $($results.Count) objects" -ForegroundColor Cyan

$output = $results | Select-Object `
    @{N='CheckID'; E={'USR-035'}}, `
    @{N='CheckName'; E={'Accounts with Suspicious Naming Patterns'}}, `
    @{N='RiskScore'; E={5}}, `
    @{N='Severity'; E={'MEDIUM'}}, `
    @{N='MITRE'; E={'T1136.002'}}, `
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
                adSuiteCheckId    = 'USR-035'
                adSuiteCheckName  = 'Accounts_with_Suspicious_Naming_Patterns'
                adSuiteMEDIUM   = 'MEDIUM'
                adSuiteUsers_Accounts   = 'Users_Accounts'
                adSuiteFlag       = $true
            }
            Aces      = @()
            IsDeleted = $false
            IsACLProtected = $false
        })
    }

    $bhTs   = Get-Date -Format 'yyyyMMdd_HHmmss'
    $bhFile = Join-Path $bhDir "USR-035_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'users'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────
