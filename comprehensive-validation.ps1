#!/usr/bin/env powershell
# Task 3.6: Comprehensive Validation of ALL adsi.ps1 Files
# Run PowerShell AST parser on ALL adsi.ps1 files to verify 100% success rate

Write-Host "=== AD Suite Comprehensive Validation ===" -ForegroundColor Cyan
Write-Host "Task 3.6: Verifying all fixes with comprehensive validation" -ForegroundColor Yellow
Write-Host ""

# Initialize tracking structures
$validationResults = @{
    TotalScanned = 0
    TotalPassed = 0
    TotalFailed = 0
    FailedFiles = @()
    ByCategory = @{}
    PatternSummary = @{
        PatternA = @{ Fixed = 0; Files = @() }
        PatternB = @{ Fixed = 0; Files = @() }
        PatternC = @{ Fixed = 0; Files = @() }
        PatternD = @{ Fixed = 0; Files = @() }
        PatternE = @{ Fixed = 0; Files = @() }
        PatternF = @{ Fixed = 0; Files = @() }
        PatternG = @{ Fixed = 0; Files = @() }
        PatternH = @{ Fixed = 0; Files = @() }
        PatternI = @{ Fixed = 0; Files = @() }
        Passing = @{ Count = 0; Files = @() }
    }
}

# Function to classify error patterns (for historical tracking)
function Get-ErrorPattern {
    param($errors, $filePath)
    
    if ($errors.Count -eq 0) { return "PASS" }
    
    $firstError = $errors[0]
    $errorMsg = $firstError.Message
    $errorLine = $firstError.Extent.StartLineNumber
    
    # Pattern classification based on error signatures from design document
    if ($errorMsg -match "Missing closing '\)' in expression" -and $errorLine -eq 44) { return "A" }
    if ($errorMsg -match "Missing closing '\)' in expression" -and $errorLine -eq 30) { return "B" }
    if ($errorMsg -match "Missing closing '\)' in expression" -and $errorLine -eq 29) { return "C" }
    if ($errors.Count -ge 5 -and ($errorMsg -match "Missing closing '\)'" -or $errorMsg -match "string is missing the terminator")) { return "D" }
    if ($errorMsg -match "string is missing the terminator" -and $errorLine -gt 160) { return "E" }
    if ($errorMsg -match "Unexpected token '\}'" -and $errorLine -eq 46) { return "F" }
    if ($errorMsg -match "Catch block must be the last catch block") { return "G" }
    if ($errorMsg -match "Unexpected token '`n" -and $errorLine -gt 200) { return "H" }
    if ($filePath -match "GPO-051" -and $errorMsg -match "string is missing the terminator") { return "I" }
    
    return "UNKNOWN"
}

# Function to get category from file path
function Get-Category {
    param($filePath)
    
    $pathParts = $filePath -split [regex]::Escape([System.IO.Path]::DirectorySeparatorChar)
    
    # Find the category directory (parent of the check directory)
    for ($i = 0; $i -lt $pathParts.Length - 2; $i++) {
        if ($pathParts[$i+2] -eq "adsi.ps1") {
            return $pathParts[$i]
        }
    }
    
    return "UNKNOWN"
}

Write-Host "Scanning for ALL adsi.ps1 files..." -ForegroundColor Green

# Find all adsi.ps1 files recursively
$adsiFiles = Get-ChildItem -Path . -Recurse -Filter "adsi.ps1" -File | Where-Object {
    # Exclude backup directories
    $_.FullName -notmatch "backups_"
}

Write-Host "Found $($adsiFiles.Count) adsi.ps1 files to validate" -ForegroundColor Green
Write-Host ""

# Process each file
foreach ($file in $adsiFiles) {
    $validationResults.TotalScanned++
    $relativePath = $file.FullName.Replace((Get-Location).Path, "").TrimStart('\', '/')
    $category = Get-Category $relativePath
    
    # Initialize category tracking
    if (-not $validationResults.ByCategory.ContainsKey($category)) {
        $validationResults.ByCategory[$category] = @{ Pass = 0; Fail = 0; Files = @() }
    }
    
    Write-Host "[$($validationResults.TotalScanned)/$($adsiFiles.Count)] Validating: $relativePath" -ForegroundColor Gray
    
    try {
        # Parse file with PowerShell AST parser
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$errors)
        
        if ($errors.Count -eq 0) {
            # File passes validation
            $validationResults.TotalPassed++
            $validationResults.ByCategory[$category].Pass++
            $validationResults.PatternSummary.Passing.Count++
            $validationResults.PatternSummary.Passing.Files += $relativePath
            
            Write-Host "  ✓ PASS" -ForegroundColor Green
        } else {
            # File has parse errors
            $validationResults.TotalFailed++
            $validationResults.ByCategory[$category].Fail++
            
            $pattern = Get-ErrorPattern $errors $relativePath
            $firstError = $errors[0]
            
            $failureInfo = [PSCustomObject]@{
                File = $relativePath
                Category = $category
                Pattern = $pattern
                ErrorCount = $errors.Count
                FirstError = @{
                    Line = $firstError.Extent.StartLineNumber
                    Column = $firstError.Extent.StartColumnNumber
                    Message = $firstError.Message
                }
                AllErrors = $errors | ForEach-Object {
                    "Line $($_.Extent.StartLineNumber): $($_.Message)"
                }
            }
            
            $validationResults.FailedFiles += $failureInfo
            $validationResults.ByCategory[$category].Files += $failureInfo
            
            # Track by pattern for summary
            if ($pattern -ne "UNKNOWN" -and $pattern -ne "PASS") {
                $validationResults.PatternSummary["Pattern$pattern"].Files += $relativePath
            }
            
            Write-Host "  ✗ FAIL ($($errors.Count) errors)" -ForegroundColor Red
            Write-Host "    Pattern: $pattern" -ForegroundColor Yellow
            Write-Host "    First Error: Line $($firstError.Extent.StartLineNumber) - $($firstError.Message)" -ForegroundColor Red
        }
    } catch {
        Write-Host "  ✗ ERROR: Failed to parse file - $($_.Exception.Message)" -ForegroundColor Magenta
        $validationResults.TotalFailed++
        $validationResults.ByCategory[$category].Fail++
    }
}

Write-Host ""
Write-Host "=== COMPREHENSIVE VALIDATION REPORT ===" -ForegroundColor Cyan
Write-Host ""

# Overall Results
Write-Host "OVERALL RESULTS:" -ForegroundColor Yellow
Write-Host "  Total Scripts Scanned: $($validationResults.TotalScanned)" -ForegroundColor White
Write-Host "  Passed (Zero Errors): $($validationResults.TotalPassed)" -ForegroundColor Green
Write-Host "  Failed (Has Errors): $($validationResults.TotalFailed)" -ForegroundColor Red

$successRate = if ($validationResults.TotalScanned -gt 0) { 
    [math]::Round(($validationResults.TotalPassed / $validationResults.TotalScanned) * 100, 2) 
} else { 0 }

Write-Host "  Success Rate: $successRate%" -ForegroundColor $(if ($successRate -eq 100) { "Green" } else { "Yellow" })
Write-Host ""

# Target Achievement
if ($validationResults.TotalFailed -eq 0) {
    Write-Host "🎯 TARGET ACHIEVED: 100% ADSI Success Rate!" -ForegroundColor Green
    Write-Host "   All adsi.ps1 files parse with zero errors" -ForegroundColor Green
} else {
    Write-Host "❌ TARGET NOT MET: $($validationResults.TotalFailed) files still have parse errors" -ForegroundColor Red
    Write-Host "   Target: Fail count = 0 (100% ADSI success rate)" -ForegroundColor Yellow
}
Write-Host ""

# Results by Category
Write-Host "RESULTS BY CATEGORY:" -ForegroundColor Yellow
$sortedCategories = $validationResults.ByCategory.Keys | Sort-Object
foreach ($category in $sortedCategories) {
    $catData = $validationResults.ByCategory[$category]
    $total = $catData.Pass + $catData.Fail
    $catRate = if ($total -gt 0) { [math]::Round(($catData.Pass / $total) * 100, 1) } else { 0 }
    
    $statusColor = if ($catData.Fail -eq 0) { "Green" } else { "Red" }
    Write-Host "  $category`: $($catData.Pass)/$total ($catRate%) " -ForegroundColor $statusColor -NoNewline
    if ($catData.Fail -gt 0) {
        Write-Host "[$($catData.Fail) failed]" -ForegroundColor Red
    } else {
        Write-Host "[All passed]" -ForegroundColor Green
    }
}
Write-Host ""

# Pattern Summary (Historical tracking of what was fixed)
Write-Host "FIX SUMMARY BY PATTERN:" -ForegroundColor Yellow
$totalFixed = 0
foreach ($patternKey in @("PatternA", "PatternB", "PatternC", "PatternD", "PatternE", "PatternF", "PatternG", "PatternH", "PatternI")) {
    $pattern = $patternKey.Substring(7) # Remove "Pattern" prefix
    $fixedCount = $validationResults.PatternSummary[$patternKey].Files.Count
    $totalFixed += $fixedCount
    
    $description = switch ($pattern) {
        "A" { "PropertiesToLoad line 44 break" }
        "B" { "PropertiesToLoad line 30 break" }
        "C" { "PropertiesToLoad line 29 break" }
        "D" { "Two PropertiesToLoad + BH export" }
        "E" { "BloodHound export string terminator" }
        "F" { "TMGMT extra brace" }
        "G" { "TRST catch block ordering" }
        "H" { "DC unclosed Write-Host strings" }
        "I" { "GPO-051 regex hashtable" }
    }
    
    if ($fixedCount -gt 0) {
        Write-Host "  Pattern $pattern ($description): $fixedCount files" -ForegroundColor Green
    } else {
        Write-Host "  Pattern $pattern ($description): 0 files" -ForegroundColor Gray
    }
}

$passingCount = $validationResults.PatternSummary.Passing.Count
Write-Host "  Already Passing (no fixes needed): $passingCount files" -ForegroundColor Cyan
Write-Host "  Total Scripts Processed: $($totalFixed + $passingCount)" -ForegroundColor White
Write-Host ""

# Failed Files Detail (if any)
if ($validationResults.TotalFailed -gt 0) {
    Write-Host "FAILED FILES DETAIL:" -ForegroundColor Red
    foreach ($failure in $validationResults.FailedFiles) {
        Write-Host "  File: $($failure.File)" -ForegroundColor Red
        Write-Host "    Category: $($failure.Category)" -ForegroundColor Yellow
        Write-Host "    Pattern: $($failure.Pattern)" -ForegroundColor Yellow
        Write-Host "    Error Count: $($failure.ErrorCount)" -ForegroundColor Red
        Write-Host "    First Error: Line $($failure.FirstError.Line) - $($failure.FirstError.Message)" -ForegroundColor Red
        
        if ($failure.ErrorCount -gt 1) {
            Write-Host "    All Errors:" -ForegroundColor Red
            foreach ($error in $failure.AllErrors) {
                Write-Host "      $error" -ForegroundColor Red
            }
        }
        Write-Host ""
    }
}

# Save detailed results to JSON
$reportData = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Task = "3.6 Comprehensive Validation"
    Summary = @{
        TotalScanned = $validationResults.TotalScanned
        TotalPassed = $validationResults.TotalPassed
        TotalFailed = $validationResults.TotalFailed
        SuccessRate = $successRate
        TargetAchieved = ($validationResults.TotalFailed -eq 0)
    }
    ByCategory = $validationResults.ByCategory
    PatternSummary = $validationResults.PatternSummary
    FailedFiles = $validationResults.FailedFiles
}

$reportPath = "task-3.6-comprehensive-validation-report.json"
$reportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8
Write-Host "Detailed report saved to: $reportPath" -ForegroundColor Cyan

# Final Status
Write-Host ""
Write-Host "=== FINAL STATUS ===" -ForegroundColor Cyan
if ($validationResults.TotalFailed -eq 0) {
    Write-Host "✅ SUCCESS: All adsi.ps1 files parse with zero errors" -ForegroundColor Green
    Write-Host "🎯 100% ADSI Success Rate Achieved!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Task 3.6 COMPLETED: Comprehensive validation successful" -ForegroundColor Green
} else {
    Write-Host "❌ INCOMPLETE: $($validationResults.TotalFailed) files still have parse errors" -ForegroundColor Red
    Write-Host "🎯 Target: 100% ADSI Success Rate (0 failed files)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Task 3.6 NEEDS ATTENTION: Additional fixes required" -ForegroundColor Red
}

Write-Host "=== END COMPREHENSIVE VALIDATION ===" -ForegroundColor Cyan