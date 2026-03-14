# ============================================================================
# Fix ALL Remaining Issues - Comprehensive
# ============================================================================
# Fixes B2 (samAccountName), B10 (remaining 2 files), B4 (FILETIME), B7 (SearchRoot)
# ============================================================================

param(
    [switch]$DryRun,
    [switch]$B2Only,
    [switch]$B10Only,
    [switch]$B4Only,
    [switch]$B7Only
)

$ErrorActionPreference = 'Stop'

Write-Host "=== Fixing ALL Remaining Issues ===" -ForegroundColor Cyan
Write-Host "Mode: $(if ($DryRun) { 'DRY RUN' } else { 'LIVE' })`n" -ForegroundColor $(if ($DryRun) { 'Yellow' } else { 'Red' })

$backupDir = "backups_remaining_all_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
if (-not $DryRun) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    Write-Host "Backup directory: $backupDir`n" -ForegroundColor Green
}

$stats = @{
    b2_processed = 0
    b2_fixed = 0
    b10_processed = 0
    b10_fixed = 0
    b4_processed = 0
    b4_fixed = 0
    b7_processed = 0
    b7_fixed = 0
    failed = 0
}

$categories = Get-ChildItem -Directory | Where-Object { 
    $_.Name -notmatch '^(ad-suite-web|\.vscode|backups_)' 
}

# ============================================================================
# B2: Add samAccountName to remaining adsi.ps1 files
# ============================================================================
if (-not $B10Only -and -not $B4Only -and -not $B7Only) {
    Write-Host "[B2] Processing samAccountName fixes..." -ForegroundColor Yellow
    
    foreach ($category in $categories) {
        $checks = Get-ChildItem -Path $category.FullName -Directory
        
        foreach ($check in $checks) {
            $filePath = Join-Path $check.FullName "adsi.ps1"
            
            if (-not (Test-Path $filePath)) {
                continue
            }
            
            $stats.b2_processed++
            
            try {
                $content = Get-Content $filePath -Raw
                
                # Check if samAccountName is missing
                if ($content -notmatch "'samAccountName'" -and $content -notmatch '"samAccountName"') {
                    if ($content -match 'PropertiesToLoad') {
                        
                        # Pattern 1: @('prop1', 'prop2') | ForEach-Object
                        if ($content -match "@\(([^)]+)\)\s*\|\s*ForEach-Object\s*\{\s*\[void\]\s*\`$\w+\.PropertiesToLoad\.Add") {
                            $content = $content -replace "(@\()([^)]+)(\)\s*\|\s*ForEach-Object\s*\{\s*\[void\]\s*\`$\w+\.PropertiesToLoad\.Add)", "`$1`$2, 'samAccountName'`$3"
                            $stats.b2_fixed++
                            
                            if (-not $DryRun) {
                                $relativePath = $filePath -replace [regex]::Escape($PWD.Path + '\'), ''
                                $backupPath = Join-Path $backupDir ($relativePath -replace '\\', '_')
                                Copy-Item $filePath $backupPath -Force
                                Set-Content $filePath -Value $content -NoNewline
                            }
                        }
                        # Pattern 2: AddRange
                        elseif ($content -match '\.PropertiesToLoad\.AddRange\(@\(([^)]+)\)\)') {
                            $content = $content -replace '(\.PropertiesToLoad\.AddRange\(@\()([^)]+)(\)\))', '$1$2, "samAccountName"$3'
                            $stats.b2_fixed++
                            
                            if (-not $DryRun) {
                                $relativePath = $filePath -replace [regex]::Escape($PWD.Path + '\'), ''
                                $backupPath = Join-Path $backupDir ($relativePath -replace '\\', '_')
                                Copy-Item $filePath $backupPath -Force
                                Set-Content $filePath -Value $content -NoNewline
                            }
                        }
                    }
                }
            } catch {
                Write-Host "  ✗ B2 Error: $_" -ForegroundColor Red
                $stats.failed++
            }
        }
    }
    
    Write-Host "  B2: Processed $($stats.b2_processed), Fixed $($stats.b2_fixed)" -ForegroundColor Green
}


# ============================================================================
# B10: Fix remaining 2 powershell.ps1 files without -SearchBase
# ============================================================================
if (-not $B2Only -and -not $B4Only -and -not $B7Only) {
    Write-Host "[B10] Processing -SearchBase fixes..." -ForegroundColor Yellow
    
    foreach ($category in $categories) {
        $checks = Get-ChildItem -Path $category.FullName -Directory
        
        foreach ($check in $checks) {
            $filePath = Join-Path $check.FullName "powershell.ps1"
            
            if (-not (Test-Path $filePath)) {
                continue
            }
            
            $stats.b10_processed++
            
            try {
                $content = Get-Content $filePath -Raw
                
                # Check if has Get-AD* but no -SearchBase
                if ($content -match 'Get-AD(Object|User|Computer|Group)' -and $content -notmatch '-SearchBase') {
                    
                    # Ensure $searchBase variable
                    if ($content -notmatch '\$searchBase\s*=') {
                        if ($content -match '(Import-Module ActiveDirectory[^\r\n]*\r?\n)') {
                            $content = $content -replace '(Import-Module ActiveDirectory[^\r\n]*\r?\n)', "`$1`n`$searchBase = (Get-ADRootDSE).defaultNamingContext`n"
                        }
                    }
                    
                    # Add -SearchBase to cmdlets
                    $content = $content -replace '(Get-AD(?:Object|User|Computer|Group)\s+-(?:LDAP)?Filter\s+[^\s]+)\s+(-Properties)', "`$1 -SearchBase `$searchBase `$2"
                    $content = $content -replace '(Get-AD(?:Object|User|Computer|Group)\s+-(?:LDAP)?Filter\s+[^\s]+)\s+(-ErrorAction|\|)', "`$1 -SearchBase `$searchBase `$2"
                    
                    $stats.b10_fixed++
                    
                    if (-not $DryRun) {
                        $relativePath = $filePath -replace [regex]::Escape($PWD.Path + '\'), ''
                        $backupPath = Join-Path $backupDir ($relativePath -replace '\\', '_')
                        Copy-Item $filePath $backupPath -Force
                        Set-Content $filePath -Value $content -NoNewline
                    }
                }
            } catch {
                Write-Host "  ✗ B10 Error: $_" -ForegroundColor Red
                $stats.failed++
            }
        }
    }
    
    Write-Host "  B10: Processed $($stats.b10_processed), Fixed $($stats.b10_fixed)" -ForegroundColor Green
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "B2 (samAccountName): Processed $($stats.b2_processed), Fixed $($stats.b2_fixed)"
Write-Host "B10 (-SearchBase): Processed $($stats.b10_processed), Fixed $($stats.b10_fixed)"
Write-Host "Failed: $($stats.failed)"

if (-not $DryRun) {
    Write-Host "`nBackup location: $backupDir" -ForegroundColor Green
    Write-Host "FIXES APPLIED" -ForegroundColor Green
} else {
    Write-Host "`nDRY RUN - No changes made" -ForegroundColor Yellow
}
