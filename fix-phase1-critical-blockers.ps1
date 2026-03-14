# ============================================================================
# Phase 1: Fix Critical Blockers for BloodHound Export Eligibility
# ============================================================================
# This script fixes A1 and A2 critical blockers identified in the audit
# 
# A1: Store FindAll() in $results variable (12 files)
# A2: Add 'objectSid' to PropertiesToLoad (762 files)
#
# SAFETY: Creates backups before modification
# ============================================================================

param(
    [switch]$DryRun,
    [switch]$NoBackup,
    [string]$BackupDir = "backups_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
)

$ErrorActionPreference = 'Stop'

Write-Host "=== Phase 1: Critical Blocker Fixes ===" -ForegroundColor Cyan
Write-Host "Mode: $(if ($DryRun) { 'DRY RUN (no changes)' } else { 'LIVE (will modify files)' })" -ForegroundColor $(if ($DryRun) { 'Yellow' } else { 'Red' })
Write-Host ""

if (-not $DryRun -and -not $NoBackup) {
    Write-Host "Creating backup directory: $BackupDir" -ForegroundColor Green
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
}

$stats = @{
    A1_fixed = 0
    A2_fixed = 0
    A1_failed = 0
    A2_failed = 0
    files_processed = 0
    files_backed_up = 0
}

# Get all adsi.ps1 files
$categories = Get-ChildItem -Directory | Where-Object { 
    $_.Name -notmatch '^(ad-suite-web|\.vscode|backups)' 
}

$adsiFiles = @()
foreach ($cat in $categories) {
    $checks = Get-ChildItem -Path $cat.FullName -Directory
    foreach ($check in $checks) {
        $adsiPath = Join-Path $check.FullName "adsi.ps1"
        if (Test-Path $adsiPath) {
            $adsiFiles += $adsiPath
        }
    }
}

Write-Host "Found $($adsiFiles.Count) adsi.ps1 files to process" -ForegroundColor Cyan
Write-Host ""

foreach ($filePath in $adsiFiles) {
    $stats.files_processed++
    $relativePath = $filePath -replace [regex]::Escape($PWD.Path + '\'), ''
    $modified = $false
    
    try {
        $content = Get-Content $filePath -Raw -ErrorAction Stop
        $originalContent = $content
        
        # ====================================================================
        # FIX A1: Store FindAll() in $results variable
        # ====================================================================
        # Pattern: $searcher.FindAll() | ForEach-Object {
        # Replace with: $results = $searcher.FindAll()
        #               $results | ForEach-Object {
        
        if ($content -match '\$searcher\.FindAll\(\)\s*\|\s*ForEach-Object\s*\{') {
            Write-Host "[A1] Fixing: $relativePath" -ForegroundColor Yellow
            
            # Replace the pattern
            $content = $content -replace '(\$searcher\.FindAll\(\))\s*\|\s*(ForEach-Object\s*\{)', '$results = $searcher.FindAll()' + "`n`$results | `$2"
            
            if ($content -ne $originalContent) {
                $stats.A1_fixed++
                $modified = $true
                Write-Host "  ✓ A1 fixed: FindAll() now stored in `$results" -ForegroundColor Green
            }
        }
        
        # ====================================================================
        # FIX A2: Add 'objectSid' to PropertiesToLoad
        # ====================================================================
        # Find PropertiesToLoad.Add() calls and check if objectSid is present
        
        if ($content -match 'PropertiesToLoad' -and $content -notmatch "PropertiesToLoad.*'objectSid'|PropertiesToLoad.*`"objectSid`"") {
            Write-Host "[A2] Fixing: $relativePath" -ForegroundColor Yellow
            
            # Find the PropertiesToLoad array pattern
            # Pattern 1: @('prop1', 'prop2') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
            if ($content -match "@\([^)]+\)\s*\|\s*ForEach-Object\s*\{\s*\[void\]\s*\`$searcher\.PropertiesToLoad\.Add\(\`$_\)\s*\}") {
                # Add 'objectSid' to the array
                $content = $content -replace "(@\()([^)]+)(\)\s*\|\s*ForEach-Object)", "`$1`$2, 'objectSid'`$3"
                $stats.A2_fixed++
                $modified = $true
                Write-Host "  ✓ A2 fixed: Added 'objectSid' to PropertiesToLoad array" -ForegroundColor Green
            }
            # Pattern 2: $searcher.PropertiesToLoad.Add('prop')
            elseif ($content -match '\$searcher\.PropertiesToLoad\.Add\(') {
                # Find the last PropertiesToLoad.Add() call and add objectSid after it
                $lastAddMatch = [regex]::Matches($content, '\[void\]\s*\$searcher\.PropertiesToLoad\.Add\([^)]+\)')
                if ($lastAddMatch.Count -gt 0) {
                    $lastAdd = $lastAddMatch[$lastAddMatch.Count - 1]
                    $insertPos = $lastAdd.Index + $lastAdd.Length
                    $content = $content.Insert($insertPos, "`n[void]`$searcher.PropertiesToLoad.Add('objectSid')")
                    $stats.A2_fixed++
                    $modified = $true
                    Write-Host "  ✓ A2 fixed: Added 'objectSid' to PropertiesToLoad" -ForegroundColor Green
                }
            }
        }
        
        # ====================================================================
        # Write changes if modified
        # ====================================================================
        
        if ($modified) {
            if ($DryRun) {
                Write-Host "  [DRY RUN] Would modify: $relativePath" -ForegroundColor Cyan
            } else {
                # Create backup
                if (-not $NoBackup) {
                    $backupPath = Join-Path $BackupDir $relativePath
                    $backupDir = Split-Path $backupPath -Parent
                    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
                    Copy-Item $filePath $backupPath -Force
                    $stats.files_backed_up++
                }
                
                # Write modified content
                Set-Content -Path $filePath -Value $content -Encoding UTF8 -NoNewline
                Write-Host "  ✓ File updated: $relativePath" -ForegroundColor Green
            }
        }
        
        if ($stats.files_processed % 100 -eq 0) {
            Write-Host "  Progress: $($stats.files_processed)/$($adsiFiles.Count) files processed..." -ForegroundColor Gray
        }
        
    } catch {
        Write-Host "  ✗ Error processing $relativePath`: $_" -ForegroundColor Red
        if ($content -match '\$searcher\.FindAll\(\)\s*\|\s*ForEach-Object') {
            $stats.A1_failed++
        }
        if ($content -match 'PropertiesToLoad' -and $content -notmatch 'objectSid') {
            $stats.A2_failed++
        }
    }
}

Write-Host ""
Write-Host "=== Fix Summary ===" -ForegroundColor Cyan
Write-Host "Files processed: $($stats.files_processed)"
Write-Host "Files backed up: $($stats.files_backed_up)"
Write-Host ""
Write-Host "A1 (FindAll stored):" -ForegroundColor Yellow
Write-Host "  Fixed: $($stats.A1_fixed)"
Write-Host "  Failed: $($stats.A1_failed)"
Write-Host ""
Write-Host "A2 (objectSid added):" -ForegroundColor Yellow
Write-Host "  Fixed: $($stats.A2_fixed)"
Write-Host "  Failed: $($stats.A2_failed)"
Write-Host ""

if ($DryRun) {
    Write-Host "DRY RUN COMPLETE - No files were modified" -ForegroundColor Yellow
    Write-Host "Run without -DryRun to apply changes" -ForegroundColor Yellow
} else {
    Write-Host "FIXES APPLIED" -ForegroundColor Green
    if (-not $NoBackup) {
        Write-Host "Backups saved to: $BackupDir" -ForegroundColor Green
    }
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Run audit script again to verify fixes"
    Write-Host "2. Test a few modified scripts manually"
    Write-Host "3. Proceed to Phase 2 fixes if audit passes"
}

# Generate fix report
$report = @"
=== Phase 1 Fix Report ===
Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Mode: $(if ($DryRun) { 'DRY RUN' } else { 'LIVE' })

Files Processed: $($stats.files_processed)
Files Backed Up: $($stats.files_backed_up)

A1 Fixes (FindAll stored):
  Success: $($stats.A1_fixed)
  Failed: $($stats.A1_failed)

A2 Fixes (objectSid added):
  Success: $($stats.A2_fixed)
  Failed: $($stats.A2_failed)

Backup Location: $BackupDir
"@

$reportPath = "FIX_PHASE1_REPORT_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$report | Out-File -FilePath $reportPath -Encoding UTF8
Write-Host "Report saved to: $reportPath" -ForegroundColor Green
