# ADSI Recovery - Process by Category
param(
    [Parameter(Mandatory=$false)]
    [string]$SuiteRoot = "C:\Users\acer\Downloads\AD_suiteXXX"
)

$ErrorActionPreference = 'Continue'
$recovered = 0
$failed = 0
$skipped = 0

Write-Host "=== ADSI Recovery by Category ===" -ForegroundColor Cyan

# Get category folders (exclude backups and hidden folders)
$categories = Get-ChildItem -Path $SuiteRoot -Directory | 
    Where-Object { $_.Name -notmatch '^\.' -and $_.Name -notmatch '^backup' -and $_.Name -ne 'ad-suite-web' -and $_.Name -ne 'AD_suiteXXX' }

Write-Host "Found $($categories.Count) categories to process"
Write-Host ""

foreach ($category in $categories) {
    Write-Host "Processing category: $($category.Name)" -ForegroundColor Yellow
    
    # Find check directories in this category
    $checkDirs = Get-ChildItem -Path $category.FullName -Directory -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -match '^[A-Z]+-\d+' }
    
    foreach ($checkDir in $checkDirs) {
        $checkName = $checkDir.Name
        $combinedPath = Join-Path $checkDir.FullName 'combined_multiengine.ps1'
        $adsiPath = Join-Path $checkDir.FullName 'adsi.ps1'
        
        if (-not (Test-Path $combinedPath)) {
            continue
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
            $cat = if ($categoryMatch.Success) { $categoryMatch.Groups[1].Value.Trim() } else { $category.Name }
            $severity = if ($severityMatch.Success) { $severityMatch.Groups[1].Value.Trim() } else { 'medium' }
            
            # Build new content
            $newContent = @"
# Check: $checkName_meta
# Category: $cat
# Severity: $severity
# ID: $checkId
# Requirements: None
# ============================================

$bodyText
"@
            
            Set-Content -Path $adsiPath -Value $newContent -Encoding UTF8 -Force
            Write-Host "  OK: $checkName" -ForegroundColor Green
            $script:recovered++
        }
        catch {
            Write-Host "  ERROR: $checkName - $($_.Exception.Message)" -ForegroundColor Red
            $script:failed++
        }
    }
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Recovered: $recovered" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor Red
Write-Host "Skipped: $skipped" -ForegroundColor Yellow
