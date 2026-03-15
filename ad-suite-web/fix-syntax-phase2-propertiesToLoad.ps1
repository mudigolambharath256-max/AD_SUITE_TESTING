# ============================================================================
# AD Suite Syntax Fix - Phase 2: PropertiesToLoad Syntax Fix
# ============================================================================
# Fixes PropertiesToLoad array syntax errors (Patterns A, B, C)
# Consolidates arrays to single line with proper closing before pipe operator
# ============================================================================

param(
    [switch]$WhatIf = $false,
    [switch]$Verbose = $false
)

# Load scan results
$scanResultsPath = "phase1-scan-results.json"
if (-not (Test-Path $scanResultsPath)) {
    Write-Error "Scan results not found. Please run fix-syntax-phase1-scan.ps1 first."
    exit 1
}

$scanResults = Get-Content $scanResultsPath | ConvertFrom-Json

# Get files that need PropertiesToLoad fixes (Patterns A, B, C)
$filesToFix = @()
$filesToFix += $scanResults.ByPattern.PatternA.Files
$filesToFix += $scanResults.ByPattern.PatternB.Files
if ($scanResults.ByPattern.PatternC) {
    $filesToFix += $scanResults.ByPattern.PatternC.Files
}

Write-Host "=== AD Suite Syntax Fix - Phase 2: PropertiesToLoad Fix ===" -ForegroundColor Cyan
Write-Host "Fixing PropertiesToLoad syntax in $($filesToFix.Count) files..." -ForegroundColor Yellow
Write-Host ""

if ($WhatIf) {
    Write-Host "WHAT-IF MODE: No files will be modified" -ForegroundColor Magenta
    Write-Host ""
}

$fixStats = @{
    TotalProcessed = 0
    SuccessfullyFixed = 0
    AlreadyFixed = 0
    Failed = @()
}

function Fix-PropertiesToLoadSyntax {
    param(
        [string]$FilePath,
        [switch]$WhatIf
    )
    
    try {
        $content = Get-Content $FilePath -Raw
        $originalContent = $content
        
        # Fix the specific pattern: missing closing brace for ForEach-Object
        # Pattern: (@('...') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
        # Should be: (@('...') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) })
        
        # Look for the broken pattern and fix it
        $pattern = '(\(@\([^)]+\)\s*\|\s*ForEach-Object\s*\{\s*\[void\]\$searcher\.PropertiesToLoad\.Add\(\$_\)\s*\})\s*$'
        $replacement = '$1)'
        
        # Apply the fix line by line to be more precise
        $lines = $content -split "`r?`n"
        $fixed = $false
        
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^\s*\(@\([^)]+\)\s*\|\s*ForEach-Object\s*\{\s*\[void\]\$searcher\.PropertiesToLoad\.Add\(\$_\)\s*\}\s*$') {
                # This line has the broken pattern - add the missing closing parenthesis
                $lines[$i] = $lines[$i] -replace '(\(@\([^)]+\)\s*\|\s*ForEach-Object\s*\{\s*\[void\]\$searcher\.PropertiesToLoad\.Add\(\$_\)\s*\})\s*$', '$1)'
                $fixed = $true
            }
        }
        
        if ($fixed) {
            $content = $lines -join "`r`n"
        }
        
        # Check if any changes were made
        if ($content -eq $originalContent) {
            return @{ Success = $true; Changed = $false; Message = "No changes needed" }
        }
        
        if (-not $WhatIf) {
            Set-Content -Path $FilePath -Value $content -Encoding UTF8
        }
        
        return @{ Success = $true; Changed = $true; Message = "Fixed PropertiesToLoad syntax" }
        
    } catch {
        return @{ Success = $false; Changed = $false; Message = "Error: $($_.Exception.Message)" }
    }
}

function Test-PowerShellSyntax {
    param([string]$FilePath)
    
    try {
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($FilePath, [ref]$null, [ref]$errors)
        return $errors.Count -eq 0
    } catch {
        return $false
    }
}

# Process each file
foreach ($relativePath in $filesToFix) {
    $fixStats.TotalProcessed++
    
    # Convert relative path to absolute path
    $parentPath = Split-Path (Get-Location) -Parent
    $filePath = Join-Path $parentPath $relativePath.Replace('C:\Users\acer\Downloads\AD_suiteXXX\', '')
    
    if (-not (Test-Path $filePath)) {
        Write-Warning "File not found: $filePath"
        $fixStats.Failed += @{ File = $relativePath; Reason = "File not found" }
        continue
    }
    
    # Check if already fixed
    if (Test-PowerShellSyntax -FilePath $filePath) {
        $fixStats.AlreadyFixed++
        if ($Verbose) {
            Write-Host "  [SKIP] $relativePath - Already passing syntax check" -ForegroundColor Green
        }
        continue
    }
    
    # Apply fix
    $result = Fix-PropertiesToLoadSyntax -FilePath $filePath -WhatIf:$WhatIf
    
    if ($result.Success) {
        if ($result.Changed) {
            # Verify the fix worked
            if (-not $WhatIf -and (Test-PowerShellSyntax -FilePath $filePath)) {
                $fixStats.SuccessfullyFixed++
                if ($Verbose) {
                    Write-Host "  [FIXED] $relativePath - $($result.Message)" -ForegroundColor Green
                }
            } elseif ($WhatIf) {
                $fixStats.SuccessfullyFixed++
                Write-Host "  [WOULD FIX] $relativePath - $($result.Message)" -ForegroundColor Yellow
            } else {
                $fixStats.Failed += @{ File = $relativePath; Reason = "Fix applied but syntax still invalid" }
                if ($Verbose) {
                    Write-Host "  [PARTIAL] $relativePath - Fix applied but syntax still invalid" -ForegroundColor Red
                }
            }
        } else {
            $fixStats.AlreadyFixed++
            if ($Verbose) {
                Write-Host "  [SKIP] $relativePath - $($result.Message)" -ForegroundColor Gray
            }
        }
    } else {
        $fixStats.Failed += @{ File = $relativePath; Reason = $result.Message }
        if ($Verbose) {
            Write-Host "  [ERROR] $relativePath - $($result.Message)" -ForegroundColor Red
        }
    }
}

# Generate summary report
Write-Host ""
Write-Host "=== PHASE 2 FIX RESULTS ===" -ForegroundColor Cyan
Write-Host "Total Files Processed: $($fixStats.TotalProcessed)" -ForegroundColor White
Write-Host "Successfully Fixed: $($fixStats.SuccessfullyFixed)" -ForegroundColor Green
Write-Host "Already Fixed: $($fixStats.AlreadyFixed)" -ForegroundColor Gray
Write-Host "Failed to Fix: $($fixStats.Failed.Count)" -ForegroundColor Red
Write-Host ""

if ($fixStats.Failed.Count -gt 0) {
    Write-Host "=== FAILED FILES ===" -ForegroundColor Red
    foreach ($failure in $fixStats.Failed) {
        Write-Host "  - $($failure.File): $($failure.Reason)" -ForegroundColor Red
    }
    Write-Host ""
}

# Save results
$reportPath = "phase2-fix-results.json"
$fixStats | ConvertTo-Json -Depth 10 | Out-File $reportPath -Encoding UTF8
Write-Host "Detailed results saved to: $reportPath" -ForegroundColor Green

if (-not $WhatIf) {
    Write-Host ""
    Write-Host "Phase 2 PropertiesToLoad fixes complete!" -ForegroundColor Green
    Write-Host "Run the Phase 1 scanner again to verify fixes..." -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "Phase 2 What-If analysis complete!" -ForegroundColor Green
    Write-Host "Run without -WhatIf to apply the fixes..." -ForegroundColor Yellow
}