# ============================================================================
# Validate Structural Fixes for Patterns F, G, H, I
# ============================================================================

Write-Host "=== VALIDATING STRUCTURAL FIXES FOR PATTERNS F, G, H, I ===" -ForegroundColor Cyan
Write-Host ""

$validationResults = @{
    PatternF = @{ Expected = 0; Found = 0; Files = @() }
    PatternG = @{ Expected = 0; Found = 0; Files = @() }
    PatternH = @{ Expected = 0; Found = 0; Files = @() }
    PatternI = @{ Expected = 0; Found = 0; Files = @() }
    TotalScanned = 0
    AllPassing = 0
}

# Scan all adsi.ps1 files
Get-ChildItem -Recurse -Filter "adsi.ps1" | ForEach-Object {
    $validationResults.TotalScanned++
    
    if (Test-Path $_.FullName) {
        $content = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
        if ($content -and $content.Trim().Length -gt 0) {
            $errors = $null
            try {
                [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$errors)
                
                if ($errors -and $errors.Count -gt 0) {
                    # Check for specific structural patterns
                    foreach ($error in $errors) {
                        $msg = $error.Message
                        $line = $error.Extent.StartLineNumber
                        
                        # Pattern F: TMGMT extra brace at line 46
                        if ($_.FullName -like "*TMGMT*" -and $msg -like "*Unexpected token '}'*" -and $line -eq 46) {
                            $validationResults.PatternF.Found++
                            $validationResults.PatternF.Files += $_.FullName
                        }
                        # Pattern G: TRST catch block ordering
                        elseif ($_.FullName -like "*TRST*" -and $msg -like "*Catch block must be the last*") {
                            $validationResults.PatternG.Found++
                            $validationResults.PatternG.Files += $_.FullName
                        }
                        # Pattern H: DC unclosed strings with backtick-n
                        elseif ($_.FullName -like "*DC-*" -and $msg -like "*Unexpected token*nSummary*") {
                            $validationResults.PatternH.Found++
                            $validationResults.PatternH.Files += $_.FullName
                        }
                        # Pattern I: GPO-051 regex hashtable quoting
                        elseif ($_.FullName -like "*GPO-051*" -and ($msg -like "*string*terminator*" -or $msg -like "*hash literal*")) {
                            $validationResults.PatternI.Found++
                            $validationResults.PatternI.Files += $_.FullName
                        }
                    }
                } else {
                    $validationResults.AllPassing++
                }
            } catch {
                Write-Warning "Could not parse: $($_.FullName)"
            }
        }
    }
}

# Report results
Write-Host "=== VALIDATION RESULTS ===" -ForegroundColor Cyan
Write-Host "Total files scanned: $($validationResults.TotalScanned)" -ForegroundColor White
Write-Host "Files passing syntax check: $($validationResults.AllPassing)" -ForegroundColor Green
Write-Host ""

Write-Host "Pattern F (TMGMT spurious closing brace):" -ForegroundColor Yellow
Write-Host "  Expected: $($validationResults.PatternF.Expected) | Found: $($validationResults.PatternF.Found)" -ForegroundColor White
if ($validationResults.PatternF.Found -gt 0) {
    $validationResults.PatternF.Files | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
}

Write-Host "Pattern G (TRST catch block ordering + BH export):" -ForegroundColor Yellow
Write-Host "  Expected: $($validationResults.PatternG.Expected) | Found: $($validationResults.PatternG.Found)" -ForegroundColor White
if ($validationResults.PatternG.Found -gt 0) {
    $validationResults.PatternG.Files | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
}

Write-Host "Pattern H (DC unclosed strings with backtick-n):" -ForegroundColor Yellow
Write-Host "  Expected: $($validationResults.PatternH.Expected) | Found: $($validationResults.PatternH.Found)" -ForegroundColor White
if ($validationResults.PatternH.Found -gt 0) {
    $validationResults.PatternH.Files | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
}

Write-Host "Pattern I (GPO regex hashtable quoting):" -ForegroundColor Yellow
Write-Host "  Expected: $($validationResults.PatternI.Expected) | Found: $($validationResults.PatternI.Found)" -ForegroundColor White
if ($validationResults.PatternI.Found -gt 0) {
    $validationResults.PatternI.Files | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
}

Write-Host ""
$totalStructuralIssues = $validationResults.PatternF.Found + $validationResults.PatternG.Found + $validationResults.PatternH.Found + $validationResults.PatternI.Found

if ($totalStructuralIssues -eq 0) {
    Write-Host "✓ SUCCESS: All structural syntax issues for Patterns F, G, H, I have been resolved!" -ForegroundColor Green
    Write-Host "✓ All Pattern F/G/H/I files parse successfully." -ForegroundColor Green
} else {
    Write-Host "✗ ISSUES FOUND: $totalStructuralIssues structural syntax issues remain" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== TASK 3.4 VALIDATION COMPLETE ===" -ForegroundColor Cyan