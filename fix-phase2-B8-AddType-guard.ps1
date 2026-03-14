# ============================================================================
# Fix Phase 2 - B8: Add-Type Guard for combined_multiengine.ps1
# ============================================================================
# Wraps Add-Type calls in type-existence checks to prevent re-run errors
# ============================================================================

param([switch]$DryRun)

$ErrorActionPreference = 'Stop'

Write-Host "=== Phase 2 - B8: Adding Add-Type Guards ===" -ForegroundColor Cyan
Write-Host "Mode: $(if ($DryRun) { 'DRY RUN' } else { 'LIVE' })`n" -ForegroundColor $(if ($DryRun) { 'Yellow' } else { 'Red' })

$backupDir = "backups_phase2_B8_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
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

# Find all combined_multiengine.ps1 files
$categories = Get-ChildItem -Directory | Where-Object { 
    $_.Name -notmatch '^(ad-suite-web|\.vscode|backups_)' 
}

foreach ($category in $categories) {
    $checks = Get-ChildItem -Path $category.FullName -Directory
    
    foreach ($check in $checks) {
        $filePath = Join-Path $check.FullName "combined_multiengine.ps1"
        
        if (-not (Test-Path $filePath)) {
            continue
        }
        
        $stats.processed++
        $relativePath = $filePath -replace [regex]::Escape($PWD.Path + '\'), ''
        
        if ($stats.processed % 50 -eq 0) {
            Write-Host "  Processed $($stats.processed) files..." -ForegroundColor Gray
        }
        
        try {
            $content = Get-Content $filePath -Raw
            
            # Check if Add-Type exists and is not already guarded
            if ($content -match 'Add-Type' -and $content -notmatch 'PSTypeName.*Type\)') {
                
                # Extract the class name from Add-Type
                if ($content -match 'Add-Type[^@]*@"\s*(?:public\s+)?(?:class|static\s+class)\s+(\w+)') {
                    $className = $matches[1]
                    
                    # Create the guard wrapper
                    $guardedAddType = @"
if (-not ([System.Management.Automation.PSTypeName]'$className').Type) {
    Add-Type
"@
                    
                    # Replace Add-Type with guarded version
                    $content = $content -replace '(\s*)Add-Type', "$1$guardedAddType"
                    
                    # Add closing brace after the @" closing
                    $content = $content -replace '(@"\s*\r?\n)', "$1}`n"
                    
                    if (-not $DryRun) {
                        # Backup
                        $backupPath = Join-Path $backupDir ($relativePath -replace '\\', '_')
                        Copy-Item $filePath $backupPath -Force
                        
                        # Save
                        Set-Content $filePath -Value $content -NoNewline
                    }
                    
                    $stats.fixed++
                } else {
                    $stats.skipped++
                }
            } else {
                $stats.skipped++
            }
            
        } catch {
            Write-Host "  ✗ Error in $relativePath : $_" -ForegroundColor Red
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
