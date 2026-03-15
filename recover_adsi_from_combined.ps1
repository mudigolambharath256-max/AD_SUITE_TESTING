# ADSI Recovery Script - Rewritten
# Recovers adsi.ps1 files from combined_multiengine.ps1 files
# Usage: .\recover_adsi_from_combined.ps1

param(
    [Parameter(Mandatory=$false)]
    [string]$SuiteRoot = "C:\Users\acer\Downloads\AD_suiteXXX"
)

$ErrorActionPreference = 'Stop'
$recovered = 0
$failed = 0
$skipped = 0

Write-Host "=== ADSI Recovery from Combined Engine Scripts ===" -ForegroundColor Cyan
Write-Host "Suite root: $SuiteRoot"
Write-Host ""

# Helper: verify a file is a valid adsi script
function Test-AdsiContent([string]$content) {
    $hasSearcher = $content -match '\[ADSISearcher\]'
    $hasFindAll  = $content -match '\$results = \$searcher\.FindAll'
    $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$errors)
    return ($hasSearcher -and $hasFindAll -and $errors.Count -eq 0)
}

# Find all check directories
$checkDirs = Get-ChildItem -Path $SuiteRoot -Recurse -Directory | 
    Where-Object { $_.Name -match '^[A-Z]+-\d+' } |
    Where-Object { Test-Path (Join-Path $_.FullName 'combined_multiengine.ps1') }

Write-Host "Found $($checkDirs.Count) check directories with combined_multiengine.ps1"
Write-Host ""

foreach ($checkDir in $checkDirs) {
    $checkName = $checkDir.Name
    $combinedPath = Join-Path $checkDir.FullName 'combined_multiengine.ps1'
    $adsiPath = Join-Path $checkDir.FullName 'adsi.ps1'
    
    try {
        $combinedContent = Get-Content $combinedPath -Raw -ErrorAction Stop
        
        # Extract ADSI block - look for the pattern with $adsiResults
        $pattern = '\$adsiResults\s*=\s*@\(\s*\n(.*?)\n\s*\)\s*\n\s*\$results\s*\+=\s*\$adsiResults'
        $match = [regex]::Match($combinedContent, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
        
        if (-not $match.Success) {
            Write-Host "  SKIP: $checkName (no ADSI block found)" -ForegroundColor Yellow
            $script:skipped++
            continue
        }
        
        # Extract and clean the body
        $body = $match.Groups[1].Value
        $lines = $body -split "`n"
        $cleanedLines = @()
        
        foreach ($line in $lines) {
            # Remove leading indentation (8 spaces or 4 spaces)
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
        
        # Extract metadata from combined file
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
        
        # Validate before writing
        if (Test-AdsiContent $newContent) {
            Set-Content -Path $adsiPath -Value $newContent -Encoding UTF8 -Force
            Write-Host "  OK: $checkName" -ForegroundColor Green
            $script:recovered++
        } else {
            Write-Host "  FAIL (validation): $checkName" -ForegroundColor Red
            $script:failed++
        }
    }
    catch {
        Write-Host "  ERROR: $checkName - $($_.Exception.Message)" -ForegroundColor Red
        $script:failed++
    }
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Recovered: $recovered" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor Red
Write-Host "Skipped: $skipped" -ForegroundColor Yellow
