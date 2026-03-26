#requires -Version 5.1
<#
.SYNOPSIS
    Emit a lightweight catalog summary for the static UI (category grouping, no full LDAP filters).

.PARAMETER ChecksJsonPath
    Path to checks.json.

.PARAMETER ChecksOverridesPath
    Optional overrides (same as scan).

.PARAMETER OutputPath
    Default: ..\ui\catalog-summary.json
#>
[CmdletBinding()]
param(
    [string]$ChecksJsonPath,

    [string]$ChecksOverridesPath,

    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $toolsDir
if (-not $ChecksJsonPath) {
    $ChecksJsonPath = Join-Path $repoRoot 'checks.json'
}
if (-not $OutputPath) {
    $OutputPath = Join-Path $repoRoot 'ui\catalog-summary.json'
}

$defaultOv = Join-Path $repoRoot 'checks.overrides.json'
if (-not $ChecksOverridesPath -and (Test-Path -LiteralPath $defaultOv)) {
    $ChecksOverridesPath = $defaultOv
}

$modulePath = Join-Path $repoRoot 'Modules\ADSuite.Adsi.psm1'
Import-Module $modulePath -Force -ErrorAction Stop

$doc = Import-ADSuiteCatalogJson -ChecksJsonPath $ChecksJsonPath -ChecksOverridesPath $ChecksOverridesPath

$byCat = [ordered]@{}
foreach ($c in @($doc.checks)) {
    $cat = if ($c.category) { [string]$c.category } else { 'Unknown' }
    if (-not $byCat.Contains($cat)) {
        $byCat[$cat] = [System.Collections.Generic.List[object]]::new()
    }
    $byCat[$cat].Add([ordered]@{
            id       = [string]$c.id
            name     = if ($c.name) { [string]$c.name } else { [string]$c.id }
            engine   = if ($c.engine) { [string]$c.engine } else { 'ldap' }
            severity = if ($c.severity) { [string]$c.severity } else { $null }
            category = $cat
        })
}

$categories = [System.Collections.Generic.List[object]]::new()
foreach ($k in $byCat.Keys) {
    $categories.Add([ordered]@{
            name   = $k
            checks = @($byCat[$k])
        })
}

$outDoc = [ordered]@{
    schemaVersion = 1
    sourceCatalog = (Resolve-Path -LiteralPath $ChecksJsonPath).Path
    meta          = @{}
    categories    = @($categories)
}

if ($doc.meta) {
    $m = @{}
    foreach ($p in $doc.meta.PSObject.Properties) {
        $m[$p.Name] = $p.Value
    }
    $outDoc['meta'] = $m
}

$json = ($outDoc | ConvertTo-Json -Depth 12 -Compress:$false)
$dir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}
[System.IO.File]::WriteAllText($OutputPath, $json, [System.Text.UTF8Encoding]::new($true))
Write-Host "Wrote $OutputPath ($($doc.checks.Count) checks in $($categories.Count) categories)" -ForegroundColor Green
