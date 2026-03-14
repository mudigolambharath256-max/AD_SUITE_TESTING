# ============================================================================
# Fix Phase 2 - B10: Add -SearchBase to PowerShell AD Cmdlets
# ============================================================================
# Adds -SearchBase parameter to Get-ADObject, Get-ADUser, Get-ADComputer, Get-ADGroup
# ============================================================================

param([switch]$DryRun)

$ErrorActionPreference = 'Stop'

Write-Host "=== Phase 2 - B10: Adding -SearchBase to PowerShell Cmdlets ===" -ForegroundColor Cyan
Write-Host "Mode: $(if ($DryRun) { 'DRY RUN' } else { 'LIVE' })`n" -ForegroundColor $(if ($DryRun) { 'Yellow' } else { 'Red' })

$backupDir = "backups_phase2_B10_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
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

# Find all powershell.ps1 files
$categories = Get-ChildItem -Directory | Where-Object { 
    $_.Name -notmatch '^(ad-suite-web|\.vscode|backups_)' 
}

foreach ($category in $categories) {
    $checks = Get-ChildItem -Path $category.FullName -Directory
    
    foreach ($check in $checks) {
        $filePath = Join-Path $check.FullName "powershell.ps1"
        
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
            $originalContent = $content
            $modified = $false
            
            # Check if file uses Get-AD* cmdlets and doesn't have -SearchBase
            $hasADCmdlets = $content -match 'Get-AD(Object|User|Computer|Group)\b'
            $hasSearchBase = $content -match '-SearchBase'
            
            if ($hasADCmdlets -and -not $hasSearchBase) {
                # Add -SearchBase to Get-ADObject calls
                # Pattern: Get-ADObject -Filter ... -Properties ...
                # Add: -SearchBase (Get-ADRootDSE).defaultNamingContext
                
                # First, ensure we have the $searchBase variable defined
                if ($content -notmatch '\$searchBase\s*=') {
                    # Add searchBase variable after try { or at the beginning of the script
                    if ($content -match '(try\s*\{)') {
                        $content = $content -replace '(try\s*\{\s*\r?\n)', "`$1    `$searchBase = (Get-ADRootDSE).defaultNamingContext`n`n"
                    } else {
                        # Add at the beginning after comments
                        $content = $content -replace '(#[^\r\n]+\r?\n)+(\r?\n)', "`$0`$searchBase = (Get-ADRootDSE).defaultNamingContext`n`n"
                    }
                }
                
                # Add -SearchBase to Get-ADObject
                $content = $content -replace '(Get-ADObject\s+)(-Filter\s+[^\s]+)(\s+)(-Properties)', "`$1`$2 -SearchBase `$searchBase `$4"
                
                # Add -SearchBase to Get-ADUser
                $content = $content -replace '(Get-ADUser\s+)(-Filter\s+[^\s]+)(\s+)(-Properties)', "`$1`$2 -SearchBase `$searchBase `$4"
                
                # Add -SearchBase to Get-ADComputer
                $content = $content -replace '(Get-ADComputer\s+)(-Filter\s+[^\s]+)(\s+)(-Properties)', "`$1`$2 -SearchBase `$searchBase `$4"
                
                # Add -SearchBase to Get-ADGroup
                $content = $content -replace '(Get-ADGroup\s+)(-Filter\s+[^\s]+)(\s+)(-Properties)', "`$1`$2 -SearchBase `$searchBase `$4"
                
                if ($content -ne $originalContent) {
                    $stats.fixed++
                    $modified = $true
                }
            }
            
            if ($modified) {
                if (-not $DryRun) {
                    # Backup
                    $backupPath = Join-Path $backupDir ($relativePath -replace '\\', '_')
                    Copy-Item $filePath $backupPath -Force
                    
                    # Save
                    Set-Content $filePath -Value $content -NoNewline
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
