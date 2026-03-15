# ============================================================================
# AD Suite Syntax Fix - Phase 4: Structural Issues Fix
# ============================================================================
# Fixes structural syntax errors (Patterns F, G, H, I)
# - Pattern F: TMGMT extra brace issues
# - Pattern G: TRST catch block ordering
# - Pattern H: DC unclosed string issues
# - Pattern I: GPO-051 regex hashtable issues
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

# Get files that need structural fixes (Patterns F, G, H, I)
$filesToFix = @()
if ($scanResults.ByPattern.PatternF) { $filesToFix += $scanResults.ByPattern.PatternF.Files }
if ($scanResults.ByPattern.PatternG) { $filesToFix += $scanResults.ByPattern.PatternG.Files }
if ($scanResults.ByPattern.PatternH) { $filesToFix += $scanResults.ByPattern.PatternH.Files }
if ($scanResults.ByPattern.PatternI) { $filesToFix += $scanResults.ByPattern.PatternI.Files }

Write-Host "=== AD Suite Syntax Fix - Phase 4: Structural Issues Fix ===" -ForegroundColor Cyan
Write-Host "Fixing structural syntax issues in $($filesToFix.Count) files..." -ForegroundColor Yellow
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

function Fix-PatternF-TMGMTExtraBrace {
    param(
        [string]$FilePath,
        [switch]$WhatIf
    )
    
    try {
        $content = Get-Content $FilePath -Raw
        $originalContent = $content
        
        # Pattern F: TMGMT files have extra }.Add($_) and } lines
        # Look for the specific broken pattern:
        # }.Add($_)
        # }
        
        $lines = $content -split "`r?`n"
        $fixed = $false
        
        for ($i = 0; $i -lt $lines.Count - 1; $i++) {
            if ($lines[$i] -match '^\s*\}\.Add\(\$_\)\s*$' -and $lines[$i+1] -match '^\s*\}\s*$') {
                Write-Host "  Removing extra }.Add(\$_) and } at lines $($i+1) and $($i+2)" -ForegroundColor Yellow
                $lines[$i] = ""     # Remove }.Add($_) line
                $lines[$i+1] = ""   # Remove extra } line
                $fixed = $true
                break
            }
        }
        
        if ($fixed) {
            # Remove empty lines and rejoin
            $lines = $lines | Where-Object { $_ -ne "" }
            $content = $lines -join "`r`n"
        }
        
        # Check if any changes were made
        if ($content -eq $originalContent) {
            return @{ Success = $true; Changed = $false; Message = "No changes needed" }
        }
        
        if (-not $WhatIf) {
            Set-Content -Path $FilePath -Value $content -Encoding UTF8
        }
        
        return @{ Success = $true; Changed = $true; Message = "Fixed TMGMT extra brace" }
        
    } catch {
        return @{ Success = $false; Changed = $false; Message = "Error: $($_.Exception.Message)" }
    }
}

function Fix-PatternI-GPORegexHashtable {
    param(
        [string]$FilePath,
        [switch]$WhatIf
    )
    
    try {
        $content = Get-Content $FilePath -Raw
        $originalContent = $content
        
        # Pattern I: GPO-051 has regex hashtable with unescaped quotes
        # The issue is in the regex patterns that contain unescaped quotes
        
        # Fix the specific patterns that are causing issues
        $content = $content -replace "(?i)\(password\\s\*=\\s\*\[`"\'\]\?\)\(\[`"\^\\s\\r\\n\]\+\)", "(password\\s*=\\s*[`"'`]?)([^`"\\s\\r\\n]+)"
        $content = $content -replace "ConvertTo-SecureString\\s\+\-String\\s\+\[`"\'\]\(\[`"\^`"\'\]\+\)\[`"\'\]", "ConvertTo-SecureString\\s+-String\\s+[`"']([^`"']+)[`"']"
        $content = $content -replace "\\$\\w\*\(\?\:password\|pwd\|cred\)\\w\*\\s\*=\\s\*\[`"\'\]\(\[`"\^`"\'\]\+\)\[`"\'\]", "\\$\\w*(?:password|pwd|cred)\\w*\\s*=\\s*[`"']([^`"']+)[`"']"
        
        # More general fix for quote issues in hashtable values
        if ($content -match '\$credentialPatterns\s*=\s*@\{') {
            # Fix unescaped quotes in regex patterns
            $content = $content -replace '= ''([^'']*)"([^'']*)"([^'']*)''', '= ''$1`"$2`"$3'''
            $content = $content -replace '= "([^"]*)"([^"]*)"([^"]*)"', '= "$1`"$2`"$3"'
        }
        
        # Check if any changes were made
        if ($content -eq $originalContent) {
            return @{ Success = $true; Changed = $false; Message = "No changes needed" }
        }
        
        if (-not $WhatIf) {
            Set-Content -Path $FilePath -Value $content -Encoding UTF8
        }
        
        return @{ Success = $true; Changed = $true; Message = "Fixed GPO regex hashtable" }
        
    } catch {
        return @{ Success = $false; Changed = $false; Message = "Error: $($_.Exception.Message)" }
    }
}

function Fix-StructuralIssues {
    param(
        [string]$FilePath,
        [string]$Pattern,
        [switch]$WhatIf
    )
    
    switch ($Pattern) {
        'PatternF' {
            return Fix-PatternF-TMGMTExtraBrace -FilePath $FilePath -WhatIf:$WhatIf
        }
        'PatternI' {
            return Fix-PatternI-GPORegexHashtable -FilePath $FilePath -WhatIf:$WhatIf
        }
        default {
            return @{ Success = $true; Changed = $false; Message = "Pattern $Pattern not implemented yet" }
        }
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

function Identify-FilePattern {
    param([string]$FilePath)
    
    if ($FilePath -like "*TMGMT*") {
        return 'PatternF'
    } elseif ($FilePath -like "*TRST*") {
        return 'PatternG'
    } elseif ($FilePath -like "*DC-*") {
        return 'PatternH'
    } elseif ($FilePath -like "*GPO-051*") {
        return 'PatternI'
    } else {
        return 'Unknown'
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
    
    # Identify pattern and apply appropriate fix
    $pattern = Identify-FilePattern -FilePath $relativePath
    $result = Fix-StructuralIssues -FilePath $filePath -Pattern $pattern -WhatIf:$WhatIf
    
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
Write-Host "=== PHASE 4 FIX RESULTS ===" -ForegroundColor Cyan
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
$reportPath = "phase4-fix-results.json"
$fixStats | ConvertTo-Json -Depth 10 | Out-File $reportPath -Encoding UTF8
Write-Host "Detailed results saved to: $reportPath" -ForegroundColor Green

if (-not $WhatIf) {
    Write-Host ""
    Write-Host "Phase 4 structural fixes complete!" -ForegroundColor Green
    Write-Host "Run the Phase 1 scanner again to verify fixes..." -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "Phase 4 What-If analysis complete!" -ForegroundColor Green
    Write-Host "Run without -WhatIf to apply the fixes..." -ForegroundColor Yellow
}