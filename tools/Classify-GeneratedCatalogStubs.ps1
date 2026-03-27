#requires -Version 5.1
<#
.SYNOPSIS
  Summarize checks.generated.json by category and engine; flag buckets for Phase B (LDAP-first) vs ADCS vs Azure.

.PARAMETER GeneratedCatalogPath
  Path to checks.generated.json. Default: repo root checks.generated.json next to this script parent.

.EXAMPLE
  .\tools\Classify-GeneratedCatalogStubs.ps1
#>
[CmdletBinding()]
param(
    [string]$GeneratedCatalogPath
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
if (-not $GeneratedCatalogPath) {
    $GeneratedCatalogPath = Join-Path $root 'checks.generated.json'
}
if (-not (Test-Path -LiteralPath $GeneratedCatalogPath)) {
    Write-Error "File not found: $GeneratedCatalogPath"
}

$doc = Get-Content -LiteralPath $GeneratedCatalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
$checks = @($doc.checks)
Write-Host "Catalog: $GeneratedCatalogPath" -ForegroundColor Cyan
Write-Host "Total checks: $($checks.Count)" -ForegroundColor Cyan
Write-Host ""

$byCat = @{}
$byEng = @{}
$azureCats = @('Azure_AD_Integration', 'Azure_AD', 'Hybrid_Identity')
foreach ($c in $checks) {
    $cat = if ($c.category) { [string]$c.category } else { '(none)' }
    $eng = if ($c.engine) { [string]$c.engine } else { '(none)' }
    if (-not $byCat.ContainsKey($cat)) { $byCat[$cat] = 0 }
    if (-not $byEng.ContainsKey($eng)) { $byEng[$eng] = 0 }
    $byCat[$cat]++
    $byEng[$eng]++
}

Write-Host "By engine:" -ForegroundColor Yellow
$byEng.GetEnumerator() | Sort-Object Name | ForEach-Object { Write-Host ("  {0,-14} {1}" -f $_.Key, $_.Value) }

Write-Host ""
Write-Host "Buckets (for backlog triage):" -ForegroundColor Yellow
$cert = ($checks | Where-Object { $_.category -eq 'Certificate_Services' }).Count
$azure = ($checks | Where-Object { $azureCats -contains [string]$_.category }).Count
Write-Host "  Certificate_Services     $cert"
Write-Host "  Azure_AD_Integration*  $azure  (*matched categories: $($azureCats -join ', '))"

Write-Host ""
Write-Host "Top categories (count):" -ForegroundColor Yellow
$byCat.GetEnumerator() | Sort-Object { -$_.Value }, Name | Select-Object -First 25 | ForEach-Object {
    Write-Host ("  {0,-40} {1}" -f $_.Key, $_.Value)
}
