# ============================================================================
# Fix Remaining B8 & B9 Issues - Complete
# ============================================================================
# Fixes all remaining Add-Type guard and public class/Run issues
# ============================================================================

param([switch]$DryRun)

$ErrorActionPreference = 'Stop'

Write-Host "=== Fixing Remaining B8 & B9 Issues ===" -ForegroundColor Cyan
Write-Host "Mode: $(if ($DryRun) { 'DRY RUN' } else { 'LIVE' })`n" -ForegroundColor $(if ($DryRun) { 'Yellow' } else { 'Red' })

$backupDir = "backups_remaining_B8B9_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
if (-not $DryRun) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    Write-Host "Backup directory: $backupDir`n" -ForegroundColor Green
}

$stats = @{
    processed = 0
    b8_fixed = 0
    b9_class_fixed = 0
    b9_method_fixed = 0
    b9_call_added = 0
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
            $originalContent = $content
            $modified = $false
            
            # Check if file has Add-Type
            if ($content -match 'Add-Type') {
                
                # ================================================================
                # B9: Fix C# class and method (do this first)
                # ================================================================
                
                # Fix 1: Change "class Program" to "public class Program"
                if ($content -match '(?<!public\s)class Program\b') {
                    $content = $content -replace '(?<!public\s)class Program\b', 'public class Program'
                    $stats.b9_class_fixed++
                    $modified = $true
                }
                
                # Fix 2: Change "static void Main()" to "public static void Run()"
                if ($content -match 'static void Main\s*\(\s*\)') {
                    $content = $content -replace 'static void Main\s*\(\s*\)', 'public static void Run()'
                    $stats.b9_method_fixed++
                    $modified = $true
                }
                
                # ================================================================
                # B8: Add type-existence guard around Add-Type
                # ================================================================
                
                # Check if already has guard
                if ($content -notmatch 'PSTypeName.*Program.*Type\)') {
                    # Find Add-Type line and wrap it
                    if ($content -match '(\s+)(Add-Type -TypeDefinition \$csharpCode[^\r\n]+)') {
                        $indent = $matches[1]
                        $addTypeLine = $matches[2]
                        
                        # Create guarded version
                        $guardedBlock = @"
${indent}if (-not ([System.Management.Automation.PSTypeName]'Program').Type) {
${indent}    $addTypeLine
${indent}}
"@
                        # Replace the Add-Type line
                        $content = $content -replace [regex]::Escape($matches[0]), $guardedBlock
                        $stats.b8_fixed++
                        $modified = $true
                    }
                }
                
                # ================================================================
                # Add [Program]::Run() call if missing
                # ================================================================
                
                # Check if [Program]::Run() or [Program]::Main() exists
                if ($content -notmatch '\[Program\]::(Run|Main)\(\)') {
                    # Add after the Add-Type block
                    if ($content -match '(Add-Type -TypeDefinition \$csharpCode[^\r\n]+\r?\n)') {
                        $content = $content -replace '(Add-Type -TypeDefinition \$csharpCode[^\r\n]+\r?\n)', "`$1    [Program]::Run()`n"
                        $stats.b9_call_added++
                        $modified = $true
                    }
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
Write-Host "B8 fixes (Add-Type guard): $($stats.b8_fixed)"
Write-Host "B9 fixes (public class): $($stats.b9_class_fixed)"
Write-Host "B9 fixes (Run method): $($stats.b9_method_fixed)"
Write-Host "B9 fixes (Run call added): $($stats.b9_call_added)"
Write-Host "Files skipped: $($stats.skipped)"
Write-Host "Failed: $($stats.failed)"

if (-not $DryRun -and $modified) {
    Write-Host "`nBackup location: $backupDir" -ForegroundColor Green
    Write-Host "FIXES APPLIED" -ForegroundColor Green
} elseif ($DryRun) {
    Write-Host "`nDRY RUN - No changes made" -ForegroundColor Yellow
}
