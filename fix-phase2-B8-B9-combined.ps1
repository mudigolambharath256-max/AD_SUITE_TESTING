# ============================================================================
# Fix Phase 2 - B8 & B9: Add-Type Guard + Public Class/Run Method
# ============================================================================
# B8: Wraps Add-Type in type-existence check
# B9: Changes "class Program" to "public class Program" and "Main()" to "Run()"
# ============================================================================

param([switch]$DryRun)

$ErrorActionPreference = 'Stop'

Write-Host "=== Phase 2 - B8 & B9: Add-Type Guard + Public Class ===" -ForegroundColor Cyan
Write-Host "Mode: $(if ($DryRun) { 'DRY RUN' } else { 'LIVE' })`n" -ForegroundColor $(if ($DryRun) { 'Yellow' } else { 'Red' })

$backupDir = "backups_phase2_B8B9_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
if (-not $DryRun) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    Write-Host "Backup directory: $backupDir`n" -ForegroundColor Green
}

$stats = @{
    processed = 0
    b8_fixed = 0
    b9_fixed = 0
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
            
            # ================================================================
            # B9: Fix C# class and method
            # ================================================================
            # Change "class Program" to "public class Program"
            if ($content -match '\bclass Program\b' -and $content -notmatch '\bpublic class Program\b') {
                $content = $content -replace '\bclass Program\b', 'public class Program'
                $stats.b9_fixed++
                $modified = $true
            }
            
            # Change "static void Main()" to "public static void Run()"
            if ($content -match '\bstatic void Main\(\)') {
                $content = $content -replace '\bstatic void Main\(\)', 'public static void Run()'
                $stats.b9_fixed++
                $modified = $true
            }
            
            # ================================================================
            # B8: Add type-existence guard around Add-Type
            # ================================================================
            if ($content -match 'Add-Type' -and $content -notmatch 'PSTypeName.*Type\)') {
                # Add guard before Add-Type
                $content = $content -replace '(\s+)(Add-Type -TypeDefinition)', "`$1if (-not ([System.Management.Automation.PSTypeName]'Program').Type) {`n`$1    `$2"
                
                # Add closing brace and [Program]::Run() call after the Add-Type line
                $content = $content -replace '(Add-Type -TypeDefinition \$csharpCode[^\r\n]+)', "`$1`n    }`n    [Program]::Run()"
                
                $stats.b8_fixed++
                $modified = $true
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
Write-Host "B9 fixes (public class/Run): $($stats.b9_fixed)"
Write-Host "Files skipped: $($stats.skipped)"
Write-Host "Failed: $($stats.failed)"

if (-not $DryRun -and ($stats.b8_fixed -gt 0 -or $stats.b9_fixed -gt 0)) {
    Write-Host "`nBackup location: $backupDir" -ForegroundColor Green
    Write-Host "FIXES APPLIED" -ForegroundColor Green
} elseif ($DryRun) {
    Write-Host "`nDRY RUN - No changes made" -ForegroundColor Yellow
}
