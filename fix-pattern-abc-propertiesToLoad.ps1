# ============================================================================
# AD Suite Syntax Fix - Task 3.2: PropertiesToLoad Syntax Fix (Patterns A, B, C)
# ============================================================================
# Fixes PropertiesToLoad array syntax errors by consolidating arrays to single line
# with proper closing parenthesis before pipe operator
# ============================================================================

param(
    [switch]$WhatIf = $false,
    [switch]$Verbose = $false
)

$suiteRoot = "C:\Users\acer\Downloads\AD_suiteXXX"

# Get files that still need PropertiesToLoad fixes
$adsiFiles = Get-ChildItem -Path $suiteRoot -Recurse -Filter "adsi.ps1" | 
    Where-Object { $_.FullName -notmatch "\\backups" }

$filesToFix = @()

foreach ($file in $adsiFiles) {
    try {
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$errors)
        
        if ($errors.Count -gt 0) {
            # Check for Pattern A, B, C signatures
            $hasPropertiesToLoadError = $errors | Where-Object { 
                $_.Message -match "Missing closing '\)' in expression" -or
                $_.Message -match "Unexpected token" 
            }
            
            if ($hasPropertiesToLoadError) {
                # Check if it's related to PropertiesToLoad
                $content = Get-Content $file.FullName -Raw
                if ($content -match "PropertiesToLoad\.Add") {
                    $filesToFix += $file.FullName
                }
            }
        }
    } catch {
        Write-Warning "Error parsing $($file.FullName): $($_.Exception.Message)"
    }
}

Write-Host "=== AD Suite Syntax Fix - Task 3.2: PropertiesToLoad Fix ===" -ForegroundColor Cyan
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
        
        # Pattern 1: Fix missing closing parenthesis for PropertiesToLoad
        # Look for: (@('...') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
        # Should be: (@('...') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) })
        
        $pattern1 = '(\(@\([^)]+\)\s*\|\s*ForEach-Object\s*\{\s*\[void\]\$searcher\.PropertiesToLoad\.Add\(\$_\)\s*\})\s*$'
        $replacement1 = '$1)'
        
        if ($content -match $pattern1) {
            $content = $content -replace $pattern1, $replacement1
        }
        
        # Pattern 2: Fix multi-line PropertiesToLoad arrays
        # Look for arrays that span multiple lines and consolidate them
        $lines = $content -split "`r?`n"
        $fixed = $false
        
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            
            # Check if this line starts a PropertiesToLoad array but is incomplete
            if ($line -match '^\s*\(@\([^)]*$' -and $line -match 'PropertiesToLoad') {
                # This is a broken multi-line array, try to fix it
                $arrayContent = $line
                $j = $i + 1
                
                # Collect the rest of the array
                while ($j -lt $lines.Count -and $lines[$j] -notmatch '\|\s*ForEach-Object') {
                    $arrayContent += $lines[$j]
                    $j++
                }
                
                # Add the ForEach-Object part if found
                if ($j -lt $lines.Count) {
                    $arrayContent += $lines[$j]
                }
                
                # Clean up the array content and put it on one line
                $cleanArray = $arrayContent -replace "`r?`n", " " -replace '\s+', ' '
                
                # Ensure proper closing
                if ($cleanArray -notmatch '\}\)$') {
                    $cleanArray = $cleanArray -replace '\}$', '})'
                }
                
                # Replace the multi-line array with single line
                $lines[$i] = $cleanArray
                
                # Remove the extra lines
                for ($k = $i + 1; $k -le $j; $k++) {
                    if ($k -lt $lines.Count) {
                        $lines[$k] = ""
                    }
                }
                
                $fixed = $true
                break
            }
        }
        
        if ($fixed) {
            # Remove empty lines and rebuild content
            $lines = $lines | Where-Object { $_ -ne "" }
            $content = $lines -join "`r`n"
        }
        
        # Pattern 3: Fix specific broken patterns we've seen
        # Fix: } | ForEach-Object to }) | ForEach-Object
        $content = $content -replace '(\@\([^)]+\))\s*\}\s*\|\s*ForEach-Object\s*\{\s*\[void\]\$searcher\.PropertiesToLoad\.Add\(\$_\)\s*\}', '$1) | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }'
        
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
foreach ($filePath in $filesToFix) {
    $fixStats.TotalProcessed++
    
    $relativePath = $filePath.Replace($suiteRoot + "\", "")
    
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
                Write-Host "  [FIXED] $relativePath - $($result.Message)" -ForegroundColor Green
            } elseif ($WhatIf) {
                $fixStats.SuccessfullyFixed++
                Write-Host "  [WOULD FIX] $relativePath - $($result.Message)" -ForegroundColor Yellow
            } else {
                $fixStats.Failed += @{ File = $relativePath; Reason = "Fix applied but syntax still invalid" }
                Write-Host "  [PARTIAL] $relativePath - Fix applied but syntax still invalid" -ForegroundColor Red
            }
        } else {
            $fixStats.AlreadyFixed++
            if ($Verbose) {
                Write-Host "  [SKIP] $relativePath - $($result.Message)" -ForegroundColor Gray
            }
        }
    } else {
        $fixStats.Failed += @{ File = $relativePath; Reason = $result.Message }
        Write-Host "  [ERROR] $relativePath - $($result.Message)" -ForegroundColor Red
    }
}

# Generate summary report
Write-Host ""
Write-Host "=== TASK 3.2 FIX RESULTS ===" -ForegroundColor Cyan
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
$reportPath = "task-3.2-fix-results.json"
$fixStats | ConvertTo-Json -Depth 10 | Out-File $reportPath -Encoding UTF8
Write-Host "Detailed results saved to: $reportPath" -ForegroundColor Green

if (-not $WhatIf) {
    Write-Host ""
    Write-Host "Task 3.2 PropertiesToLoad fixes complete!" -ForegroundColor Green
    Write-Host "Re-running verification scan..." -ForegroundColor Yellow
    
    # Re-run the check to verify fixes
    & ".\check-pattern-abc-status.ps1"
} else {
    Write-Host ""
    Write-Host "Task 3.2 What-If analysis complete!" -ForegroundColor Green
    Write-Host "Run without -WhatIf to apply the fixes..." -ForegroundColor Yellow
}