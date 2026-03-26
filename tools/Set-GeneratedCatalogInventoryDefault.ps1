#requires -Version 5.1
<#
.SYNOPSIS
    Set every check in a catalog JSON to engine inventory (unreviewed legacy stubs) for production-safe defaults.

.PARAMETER CatalogPath
    Path to JSON (default: ..\checks.generated.json relative to tools).

.PARAMETER SkipBackup
    Do not write .pre-inventory.bak (not recommended).

.NOTES
    Preserves ldapFilter, searchBase, propertiesToLoad, etc. Promotion to risk scan: use checks.overrides.json or checks.json.
#>
[CmdletBinding()]
param(
    [string]$CatalogPath,

    [switch]$SkipBackup
)

$ErrorActionPreference = 'Stop'
$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $CatalogPath) {
    $CatalogPath = Join-Path (Split-Path -Parent $toolsDir) 'checks.generated.json'
}

if (-not (Test-Path -LiteralPath $CatalogPath)) {
    throw "Catalog not found: $CatalogPath"
}

if (-not $SkipBackup) {
    $bak = "$CatalogPath.pre-inventory.bak"
    Copy-Item -LiteralPath $CatalogPath -Destination $bak -Force
    Write-Host "Backup: $bak" -ForegroundColor Cyan
}

$jsonText = Get-Content -LiteralPath $CatalogPath -Raw -Encoding UTF8
$doc = $jsonText | ConvertFrom-Json
if ($doc.defaults) {
    $doc.defaults | Add-Member -NotePropertyName engine -NotePropertyValue 'inventory' -Force
}
$n = 0
foreach ($c in @($doc.checks)) {
    $id = if ($c.id) { [string]$c.id } else { '' }
    $cat = if ($c.category) { [string]$c.category } else { 'Unknown' }
    $desc = "Legacy stub: not in risk scan until promoted. Category: $cat; Id: $id."
    $c | Add-Member -NotePropertyName engine -NotePropertyValue 'inventory' -Force
    $c | Add-Member -NotePropertyName severity -NotePropertyValue 'info' -Force
    $c | Add-Member -NotePropertyName description -NotePropertyValue $desc -Force
    $n++
}

$out = $doc | ConvertTo-Json -Depth 25 -Compress:$false
# Match legacy exporter readability for LDAP escapes
$out = $out -replace '\\u0026', '&'
$out = $out -replace '\\u003c', '<'
$out = $out -replace '\\u003e', '>'
$out = $out -replace '\\u003d', '='
[System.IO.File]::WriteAllText($CatalogPath, $out, [System.Text.UTF8Encoding]::new($false))
Write-Host "Updated $n checks to engine=inventory in $CatalogPath" -ForegroundColor Green
