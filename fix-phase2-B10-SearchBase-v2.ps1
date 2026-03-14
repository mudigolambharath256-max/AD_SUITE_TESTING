# ============================================================================
# Fix Phase 2 - B10: Add -SearchBase to PowerShell AD Cmdlets (v2)
# ============================================================================
# Adds -SearchBase parameter to Get-ADObject, Get-ADUser, Get-ADComputer, Get-ADGroup
# Handles various formatting patterns
# ============================================================================

param([switch]$DryRun)

$ErrorActionPreference = 'Stop'

Write-Host "=== Phase 2 - B10 v2: Adding -SearchBase to PowerShell Cmdlets ===" -ForegroundColor Cyan
Write-Host "Mode: $(if ($DryRun) { 'DRY RUN' } else { 'LIVE' })`n" -ForegroundColor $(if ($DryRun) { 'Yellow' } else { 'Red' })

$backupDir = "backups_phase2_B10v2_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
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
                
                # Ensure $searchBase variable exists
                if ($content -notmatch '\$searchBase\s*=') {
                    # Add at the beginning after imports
                    if ($content -match '(Import-Module ActiveDirectory[^\r\n]*\r?\n)') {
                        $content = $content -replace '(Import-Module ActiveDirectory[^\r\n]*\r?\n)', "`$1`n`$searchBase = (Get-ADRootDSE).defaultNamingContext`n"
                    } else {
                        # Add after first comment block
                        $content = $content -replace '(#[^\r\n]+\r?\n)+(\r?\n)', "`$0`$searchBase = (Get-ADRootDSE).defaultNamingContext`n`n"
                    }
                }
                
                # Pattern 1: Get-ADObject -LDAPFilter ... -Properties ... (inline)
                # Add -SearchBase before -Properties
                $content = $content -replace '(Get-ADObject\s+-LDAPFilter\s+[^\s]+)\s+(-Properties)', "`$1 -SearchBase `$searchBase `$2"
                
                # Pattern 2: Get-ADObject -Filter ... -Properties ... (inline)
                $content = $content -replace '(Get-ADObject\s+-Filter\s+[^\s]+)\s+(-Properties)', "`$1 -SearchBase `$searchBase `$2"
                
                # Pattern 3: Get-ADUser -Filter ... -Properties ... (inline)
                $content = $content -replace '(Get-ADUser\s+-Filter\s+[^\s]+)\s+(-Properties)', "`$1 -SearchBase `$searchBase `$2"
                
                # Pattern 4: Get-ADComputer -Filter ... -Properties ... (inline)
                $content = $content -replace '(Get-ADComputer\s+-Filter\s+[^\s]+)\s+(-Properties)', "`$1 -SearchBase `$searchBase `$2"
                
                # Pattern 5: Get-ADGroup -Filter ... -Properties ... (inline)
                $content = $content -replace '(Get-ADGroup\s+-Filter\s+[^\s]+)\s+(-Properties)', "`$1 -SearchBase `$searchBase `$2"
                
                # Pattern 6: Multi-line with backticks - add before -ErrorAction or pipe
                $content = $content -replace '(Get-AD(?:Object|User|Computer|Group)[^\r\n]+\r?\n(?:[^\r\n]+\r?\n)*?)(\s+)(-ErrorAction|\|)', "`$1`$2-SearchBase `$searchBase ```n`$2`$3"
                
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
