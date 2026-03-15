# ADSI Recovery Script - Fast Version with Progress
param(
    [Parameter(Mandatory=$false)]
    [string]$SuiteRoot = "C:\Users\acer\Downloads\AD_suiteXXX"
)

$ErrorActionPreference = 'Continue'
$recovered = 0
$failed = 0
$skipped = 0
$total = 0

Write-Host "=== ADSI Recovery from Combined Engine Scripts ===" -ForegroundColor Cyan
Write-Host "Suite root: $SuiteRoot"
Write-Host ""

# Find all check directories
Write-Host "Scanning for check directories..." -ForegroundColor Yellow
$checkDirs = @(Get-ChildItem -Path $SuiteRoot -Recurse -Directory -ErrorAction SilentlyContinue | 
    Where-Object { $_.Name -match '^[A-Z]+-\d+' -and (Test-Path (Join-Path $_.FullName 'combined_multiengine.ps1')) })

$total = $checkDirs.Count
Write-Host "Found $total check directories with combined_multiengine.ps1"
Write-Host ""

$counter = 0
foreach ($checkDir in $checkDirs) {
    $counter++
    $checkName = $checkDir.Name
    $combinedPath = Join-Path $checkDir.FullName 'combined_multiengine.ps1'
    $adsiPath = Join-Path $checkDir.FullName 'adsi.ps1'
    
    if ($counter % 10 -eq 0) {
        Write-Host "Progress: $counter/$total" -ForegroundColor Cyan
    }
    
    try {
        $combinedContent = Get-Content $combinedPath -Raw -ErrorAction Stop
        
        # Extract ADSI block
        $pattern = '\$adsiResults\s*=\s*@\(\s*\n(.*?)\n\s*\)\s*\n\s*\$results\s*\+=\s*\$adsiResults'
        $match = [regex]::Match($combinedContent, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
        
        if (-not $match.Success) {
            $script:skipped++
            continue
        }
        
        # Extract and clean the body
        $body = $match.Groups[1].Value
        $lines = $body -split "`n"
        $cleanedLines = @()
        
        foreach ($line in $lines) {
            if ($line -match '^        (.*)$') {
                $cleanedLines += $matches[1]
            } elseif ($line -match '^    (.*)$') {
                $cleanedLines += $matches[1]
            } else {
                $cleanedLines += $line
            }
        }
        
        $bodyText = ($cleanedLines | Where-Object { $_ -ne $null -and $_.Trim() -ne '' }) -join "`n"
        
        # Fix the FindAll pattern
        $bodyText = $bodyText -replace 
            '\$searcher\.FindAll\(\)\s*\|\s*ForEach-Object\s*\{',
            "`$results = `$searcher.FindAll()`n`$results | ForEach-Object {"
        
        # Extract metadata
        $headerMatch = [regex]::Match($combinedContent, '# Check:\s*(.+?)(?=\n|$)')
        $idMatch = [regex]::Match($combinedContent, '# ID:\s*(.+?)(?=\n|$)')
        $categoryMatch = [regex]::Match($combinedContent, '# Category:\s*(.+?)(?=\n|$)')
        $severityMatch = [regex]::Match($combinedContent, '# Severity:\s*(.+?)(?=\n|$)')
        
        $checkName_meta = if ($headerMatch.Success) { $headerMatch.Groups[1].Value.Trim() } else { $checkName }
        $checkId = if ($idMatch.Success) { $idMatch.Groups[1].Value.Trim() } else { $checkName }
        $category = if ($categoryMatch.Success) { $categoryMatch.Groups[1].Value.Trim() } else { 'General' }
        $severity = if ($severityMatch.Success) { $severityMatch.Groups[1].Value.Trim() } else { 'medium' }
        
        # Build new content
        $newContent = @"
# Check: $checkName_meta
# Category: $category
# Severity: $severity
# ID: $checkId
# Requirements: None
# ============================================

$bodyText
"@
        
        Set-Content -Path $adsiPath -Value $newContent -Encoding UTF8 -Force
        $script:recovered++
    }
    catch {
        $script:failed++
    }
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Recovered: $recovered" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor Red
Write-Host "Skipped: $skipped" -ForegroundColor Yellow
