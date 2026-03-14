# ============================================================================
# Phase 1: Fix Critical Blockers - ALL FILE TYPES
# ============================================================================
# This script fixes A2 (objectSid missing) across ALL script types:
# - adsi.ps1
# - powershell.ps1  
# - combined_multiengine.ps1
# - csharp.cs
#
# SAFETY: Creates backups before modification
# ============================================================================

param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

Write-Host "=== Phase 1: Fix objectSid in ALL File Types ===" -ForegroundColor Cyan
Write-Host "Mode: $(if ($DryRun) { 'DRY RUN (no changes)' } else { 'LIVE (will modify files)' })" -ForegroundColor $(if ($DryRun) { 'Yellow' } else { 'Red' })
Write-Host ""

$backupDir = "backups_all_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

if (-not $DryRun) {
    Write-Host "Creating backup directory: $backupDir" -ForegroundColor Green
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
}

$stats = @{
    adsi_fixed = 0
    powershell_fixed = 0
    combined_fixed = 0
    csharp_fixed = 0
    failed = 0
    total_processed = 0
}

# Get all categories (exclude backups, node_modules, etc.)
$categories = Get-ChildItem -Directory | Where-Object { 
    $_.Name -notmatch '^(ad-suite-web|\.vscode|backups_|node_modules)' 
}

Write-Host "Found $($categories.Count) categories to process`n" -ForegroundColor Cyan

foreach ($category in $categories) {
    $checks = Get-ChildItem -Path $category.FullName -Directory -ErrorAction SilentlyContinue
    
    foreach ($check in $checks) {
        $checkPath = $check.FullName
        
        # ====================================================================
        # Process ADSI.PS1 files
        # ====================================================================
        $adsiPath = Join-Path $checkPath "adsi.ps1"
        if (Test-Path $adsiPath) {
            $stats.total_processed++
            try {
                $content = Get-Content $adsiPath -Raw
                $originalContent = $content
                
                # Check if objectSid is already present
                if ($content -match "'objectSid'" -or $content -match '"objectSid"') {
                    # Already has objectSid, skip
                    continue
                }
                
                # Check if this file uses PropertiesToLoad
                if ($content -match 'PropertiesToLoad') {
                    $relativePath = $adsiPath -replace [regex]::Escape($PWD.Path + '\'), ''
                    
                    # Pattern: @('prop1', 'prop2') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
                    if ($content -match "@\(([^)]+)\)\s*\|\s*ForEach-Object\s*\{\s*\[void\]\s*\`$searcher\.PropertiesToLoad\.Add\(\`$_\)\s*\}") {
                        Write-Host "[ADSI] $relativePath" -ForegroundColor Yellow
                        
                        # Add 'objectSid' to the array
                        $content = $content -replace "(@\()([^)]+)(\)\s*\|\s*ForEach-Object\s*\{\s*\[void\]\s*\`$searcher\.PropertiesToLoad\.Add)", "`$1`$2, 'objectSid'`$3"
                        
                        if ($content -ne $originalContent) {
                            if (-not $DryRun) {
                                # Backup
                                $backupPath = Join-Path $backupDir ($relativePath -replace '\\', '_')
                                Copy-Item $adsiPath $backupPath -Force
                                
                                # Save
                                Set-Content $adsiPath -Value $content -NoNewline
                            }
                            $stats.adsi_fixed++
                            Write-Host "  ✓ Added objectSid" -ForegroundColor Green
                        }
                    }
                }
            } catch {
                Write-Host "  ✗ Error: $_" -ForegroundColor Red
                $stats.failed++
            }
        }
        
        # ====================================================================
        # Process POWERSHELL.PS1 files
        # ====================================================================
        $ps1Path = Join-Path $checkPath "powershell.ps1"
        if (Test-Path $ps1Path) {
            $stats.total_processed++
            try {
                $content = Get-Content $ps1Path -Raw
                $originalContent = $content
                
                # Check if objectSid is already present
                if ($content -match "'objectSid'" -or $content -match '"objectSid"') {
                    continue
                }
                
                # Pattern: $properties = @('prop1', 'prop2', ...)
                if ($content -match '\$properties\s*=\s*@\(') {
                    $relativePath = $ps1Path -replace [regex]::Escape($PWD.Path + '\'), ''
                    Write-Host "[PS1] $relativePath" -ForegroundColor Yellow
                    
                    # Add 'objectSid' to the properties array
                    $content = $content -replace "(\`$properties\s*=\s*@\()([^)]+)(\))", "`$1`$2, 'objectSid'`$3"
                    
                    if ($content -ne $originalContent) {
                        if (-not $DryRun) {
                            $backupPath = Join-Path $backupDir ($relativePath -replace '\\', '_')
                            Copy-Item $ps1Path $backupPath -Force
                            Set-Content $ps1Path -Value $content -NoNewline
                        }
                        $stats.powershell_fixed++
                        Write-Host "  ✓ Added objectSid" -ForegroundColor Green
                    }
                }
            } catch {
                Write-Host "  ✗ Error: $_" -ForegroundColor Red
                $stats.failed++
            }
        }
        
        # ====================================================================
        # Process COMBINED_MULTIENGINE.PS1 files
        # ====================================================================
        $combinedPath = Join-Path $checkPath "combined_multiengine.ps1"
        if (Test-Path $combinedPath) {
            $stats.total_processed++
            try {
                $content = Get-Content $combinedPath -Raw
                $originalContent = $content
                
                # Check if objectSid is already present
                if ($content -match "'objectSid'" -or $content -match '"objectSid"') {
                    continue
                }
                
                $modified = $false
                $relativePath = $combinedPath -replace [regex]::Escape($PWD.Path + '\'), ''
                
                # Fix PowerShell properties array
                if ($content -match '\$properties\s*=\s*@\(') {
                    $content = $content -replace "(\`$properties\s*=\s*@\()([^)]+)(\))", "`$1`$2, 'objectSid'`$3"
                    $modified = $true
                }
                
                # Fix ADSI PropertiesToLoad
                if ($content -match "@\(([^)]+)\)\s*\|\s*ForEach-Object\s*\{\s*\[void\]\s*\`$searcher\.PropertiesToLoad\.Add\(\`$_\)\s*\}") {
                    $content = $content -replace "(@\()([^)]+)(\)\s*\|\s*ForEach-Object\s*\{\s*\[void\]\s*\`$searcher\.PropertiesToLoad\.Add)", "`$1`$2, 'objectSid'`$3"
                    $modified = $true
                }
                
                if ($modified -and $content -ne $originalContent) {
                    Write-Host "[COMBINED] $relativePath" -ForegroundColor Yellow
                    if (-not $DryRun) {
                        $backupPath = Join-Path $backupDir ($relativePath -replace '\\', '_')
                        Copy-Item $combinedPath $backupPath -Force
                        Set-Content $combinedPath -Value $content -NoNewline
                    }
                    $stats.combined_fixed++
                    Write-Host "  ✓ Added objectSid" -ForegroundColor Green
                }
            } catch {
                Write-Host "  ✗ Error: $_" -ForegroundColor Red
                $stats.failed++
            }
        }
        
        # ====================================================================
        # Process CSHARP.CS files
        # ====================================================================
        $csPath = Join-Path $checkPath "csharp.cs"
        if (Test-Path $csPath) {
            $stats.total_processed++
            try {
                $content = Get-Content $csPath -Raw
                $originalContent = $content
                
                # Check if objectSid is already present
                if ($content -match '"objectSid"' -or $content -match "'objectSid'") {
                    continue
                }
                
                # Pattern: searcher.PropertiesToLoad.Add("property");
                # Find the last PropertiesToLoad.Add and add objectSid after it
                if ($content -match 'PropertiesToLoad\.Add\(') {
                    $relativePath = $csPath -replace [regex]::Escape($PWD.Path + '\'), ''
                    Write-Host "[C#] $relativePath" -ForegroundColor Yellow
                    
                    # Find the last PropertiesToLoad.Add line and add objectSid after it
                    $lines = $content -split "`r?`n"
                    $lastAddIndex = -1
                    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
                        if ($lines[$i] -match 'PropertiesToLoad\.Add\(') {
                            $lastAddIndex = $i
                            break
                        }
                    }
                    
                    if ($lastAddIndex -ge 0) {
                        # Get the indentation from the last Add line
                        $indent = ""
                        if ($lines[$lastAddIndex] -match '^(\s+)') {
                            $indent = $matches[1]
                        }
                        
                        # Insert new line after the last Add
                        $newLine = "${indent}searcher.PropertiesToLoad.Add(`"objectSid`");"
                        $lines = $lines[0..$lastAddIndex] + $newLine + $lines[($lastAddIndex + 1)..($lines.Count - 1)]
                        $content = $lines -join "`r`n"
                        
                        if ($content -ne $originalContent) {
                            if (-not $DryRun) {
                                $backupPath = Join-Path $backupDir ($relativePath -replace '\\', '_')
                                Copy-Item $csPath $backupPath -Force
                                Set-Content $csPath -Value $content -NoNewline
                            }
                            $stats.csharp_fixed++
                            Write-Host "  ✓ Added objectSid" -ForegroundColor Green
                        }
                    }
                }
            } catch {
                Write-Host "  ✗ Error: $_" -ForegroundColor Red
                $stats.failed++
            }
        }
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Total files processed: $($stats.total_processed)"
Write-Host "ADSI files fixed: $($stats.adsi_fixed)"
Write-Host "PowerShell files fixed: $($stats.powershell_fixed)"
Write-Host "Combined files fixed: $($stats.combined_fixed)"
Write-Host "C# files fixed: $($stats.csharp_fixed)"
Write-Host "Failed: $($stats.failed)"
Write-Host "Total fixed: $($stats.adsi_fixed + $stats.powershell_fixed + $stats.combined_fixed + $stats.csharp_fixed)"

if (-not $DryRun) {
    Write-Host "`nBackup location: $backupDir" -ForegroundColor Green
    Write-Host "`nFIXES APPLIED" -ForegroundColor Green
} else {
    Write-Host "`nDRY RUN - No changes made" -ForegroundColor Yellow
}
