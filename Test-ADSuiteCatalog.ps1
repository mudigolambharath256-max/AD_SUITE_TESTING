#requires -Version 5.1
<#
.SYNOPSIS
    Validate catalog JSON (structure, duplicates, required fields per engine).

.PARAMETER CatalogPath
    Path to checks.json or checks.generated.json.

.PARAMETER OverridesPath
    Optional checks.overrides.json. If omitted and checks.overrides.json exists next to this script, it is loaded.

.PARAMETER LiveScan
    After validation, run Invoke-ADSuiteScan.ps1 (same directory as this script) and summarize errors/anomalies.

.PARAMETER ServerName
    Passed to LiveScan when -LiveScan is used.

.PARAMETER OutputDirectory
    Passed to LiveScan; default temp folder under out\.

.PARAMETER Category
    Optional category filter for LiveScan.

.EXAMPLE
    .\Test-ADSuiteCatalog.ps1 -CatalogPath .\checks.json
.EXAMPLE
    .\Test-ADSuiteCatalog.ps1 -CatalogPath .\checks.generated.json -LiveScan -ServerName dc01.contoso.local
#>
[CmdletBinding()]
param(
    [string]$CatalogPath,

    [string]$OverridesPath,

    [switch]$LiveScan,

    [string]$ServerName,

    [string]$OutputDirectory,

    [string[]]$Category
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $CatalogPath) {
    $unified = Join-Path $scriptDir 'checks.unified.json'
    if (Test-Path -LiteralPath $unified) {
        $CatalogPath = $unified
    } else {
        $CatalogPath = Join-Path $scriptDir 'checks.json'
    }
}

$modulePath = Join-Path $scriptDir 'Modules\ADSuite.Adsi.psm1'
Import-Module $modulePath -Force -ErrorAction Stop

$defaultOv = Join-Path $scriptDir 'checks.overrides.json'
if (-not $OverridesPath -and (Test-Path -LiteralPath $defaultOv)) {
    $OverridesPath = $defaultOv
}

try {
    $doc = Import-ADSuiteCatalogJson -ChecksJsonPath $CatalogPath -ChecksOverridesPath $OverridesPath
} catch {
    Write-Host "FATAL: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$integrity = Test-ADSuiteCatalogIntegrity -Document $doc
$warnArr = @($integrity.Warnings)
$maxW = 30
for ($i = 0; $i -lt [Math]::Min($maxW, $warnArr.Count); $i++) {
    Write-Host "WARNING: $($warnArr[$i])" -ForegroundColor DarkYellow
}
if ($warnArr.Count -gt $maxW) {
    Write-Host "... and $($warnArr.Count - $maxW) more warnings (add severity/description via overlays or curated checks.json)." -ForegroundColor DarkYellow
}
foreach ($e in $integrity.Errors) {
    Write-Host "ERROR: $e" -ForegroundColor Red
}
Write-Host "Checks: $($integrity.ChecksTotal); duplicates: $($integrity.DuplicateIds.Count)" -ForegroundColor Cyan
if ($integrity.HasBlockingErrors) {
    exit 1
}

if (-not $LiveScan) {
    exit 0
}

$scanScript = Join-Path $scriptDir 'Invoke-ADSuiteScan.ps1'
if (-not (Test-Path -LiteralPath $scanScript)) {
    Write-Host "Invoke-ADSuiteScan.ps1 not found; skipping live scan." -ForegroundColor Yellow
    exit 0
}

if (-not $OutputDirectory) {
    $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
    $OutputDirectory = Join-Path $scriptDir "out\catalog-test-$ts"
}

$args = @(
    '-NoProfile',
    '-File', $scanScript,
    '-ChecksJsonPath', $CatalogPath,
    '-OutputDirectory', $OutputDirectory,
    '-SkipCatalogValidation'
)
if ($OverridesPath) {
    $args += @('-ChecksOverridesPath', $OverridesPath)
}
if ($ServerName) {
    $args += @('-ServerName', $ServerName)
}
if ($Category -and $Category.Count -gt 0) {
    foreach ($c in $Category) {
        $args += '-Category'
        $args += $c
    }
}

Write-Host "Running live scan -> $OutputDirectory" -ForegroundColor Cyan
$p = Start-Process -FilePath 'powershell.exe' -ArgumentList $args -PassThru -Wait -NoNewWindow
if ($p.ExitCode -ne 0) {
    Write-Host "Scan process exited with $($p.ExitCode)" -ForegroundColor Red
    exit $p.ExitCode
}

$resultsPath = Join-Path $OutputDirectory 'scan-results.json'
if (-not (Test-Path -LiteralPath $resultsPath)) {
    Write-Host "No scan-results.json produced." -ForegroundColor Yellow
    exit 0
}

$scan = Get-Content -LiteralPath $resultsPath -Raw -Encoding UTF8 | ConvertFrom-Json
$agg = $scan.aggregate
Write-Host "`n--- Live scan summary ---" -ForegroundColor Cyan
Write-Host "Checks run: $($agg.checksRun); with findings: $($agg.checksWithFindings); errors: $($agg.checksWithErrors); total findings: $($agg.totalFindings)"
Write-Host "Global score: $($agg.globalScore) ($($agg.globalRiskBand))"
$errChecks = @($scan.results | Where-Object { $_.Result -eq 'Error' -or $_.Error })
foreach ($e in $errChecks) {
    Write-Host "  ERROR $($e.CheckId): $($e.Error)" -ForegroundColor Red
}
$high = @($scan.results | Where-Object { $_.FindingCount -gt 500 })
if ($high.Count -gt 0) {
    Write-Host "High finding counts (review for noisy filters):" -ForegroundColor DarkYellow
    foreach ($h in $high | Select-Object -First 15) {
        Write-Host "  $($h.CheckId): $($h.FindingCount) findings"
    }
}

exit 0
