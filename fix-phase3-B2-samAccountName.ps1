# ============================================================================
# Fix Phase 3 - B2: Add samAccountName to PropertiesToLoad
# ============================================================================
# Adds samAccountName to adsi.ps1 files for better BloodHound display names
# ============================================================================

param([switch]$DryRun)

$ErrorActionPreference = 'Stop'

Write-Host "=== Phase 3 - B2: Adding samAccountName ===" -ForegroundColor Cyan
Write-Host "Mode: $(if ($DryRun) { 'DRY RUN' } else { 'LIVE' })`n" -ForegroundColor $(if ($DryRun) { 'Yellow' } else { 'Red' })

$backupDir = "backups_phase3_B2_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
if (-not $DryRun) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    Write-Host "Backup directory: $backupDir`n" -ForegroundColor Green
}

$stats = @{
    processed = 0
    fixed = 0
    skipped = 0
    failed = 0
}

# Find all adsi.ps1 files
$categories = Get-ChildItem -Directory | Where-Object { 
    $_.Name -notmatch '^(ad-suite-web|\.vscode|backups_)' 
}

foreach ($category in $categories) {
    $checks = Get-ChildItem -Path $category.FullName -Directory
    
    foreach ($check in $checks) {
        $filePath = Join-Path $check.FullName "adsi.ps1"
        
        if (-not (Test-Path $filePath)) {
            continue
        }
        
        $stats.processed++
        
        if ($stats.processed % 50 -eq 0) {
            Write-Host "  Processed $($stats.processed) files..." -ForegroundColor Gray
        }
        
        try {
            $content = Get-Content $filePath -Raw
            
            # Check if samAccountName is missing
            if ($content -notmatch "'samAccountName'" -and $content -notmatch '"samAccountName"') {
                # Check if file has PropertiesToLoad
                if ($content -match 'PropertiesToLoad') {
                    
                    # Pattern 1: @('prop1', 'prop2') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
                    if ($content -match "@\(([^)]+)\)\s*\|\s*ForEach-Object\s*\{\s*\[void\]\s*\`$\w+\.PropertiesToLoad\.Add") {
                        $content = $content -replace "(@\()([^)]+)(\)\s*\|\s*ForEach-Object\s*\{\s*\[void\]\s*\`$\w+\.PropertiesToLoad\.Add)", "`$1`$2, 'samAccountName'`$3"
                        $stats.fixed++
                    }
                    # Pattern 2: $searcher.PropertiesToLoad.AddRange(@("prop1", "prop2"))
                    elseif ($content -match '\.PropertiesToLoad\.AddRange\(@\(([^)]+)\)\)') {
                        $content = $content -replace '(\.PropertiesToLoad\.AddRange\(@\()([^)]+)(\)\))', '$1$2, "samAccountName"$3'
                        $stats.fixed++
                    }
                    else {
                        $stats.skipped++
                    }
                    
                    if ($stats.fixed -gt 0) {
                        if (-not $DryRun) {
                            # Backup
                            $relativePath = $filePath -replace [regex]::Escape($PWD.Path + '\'), ''
                            $backupPath = Join-Path $backupDir ($relativePath -replace '\\', '_')
                            Copy-Item $filePath $backupPath -Force
                            
                            # Save
                            Set-Content $filePath -Value $content -NoNewline
                        }
                    }
                } else {
                    $stats.skipped++
                }
            } else {
                $stats.skipped++
            }
            
        } catch {
            Write-Host "  ✗ Error: $_" -ForegroundColor Red
            $stats.failed++
        }
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Files processed: $($stats.processed)"
Write-Host "Files fixed: $($stats.fixed)"
Write-Host "Files skipped: $($stats.skipped)"
Write-Host "Failed: $($stats.failed)"

if (-not $DryRun -and $stats.fixed -gt 0) {
    Write-Host "`nBackup location: $backupDir" -ForegroundColor Green
    Write-Host "FIXES APPLIED" -ForegroundColor Green
} elseif ($DryRun) {
    Write-Host "`nDRY RUN - No changes made" -ForegroundColor Yellow
}
