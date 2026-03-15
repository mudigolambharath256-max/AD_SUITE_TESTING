# AD Suite Syntax Fix - Phase 1: Pattern Identification Scanner
# ============================================================================
# Scans all adsi.ps1 files and categorizes them by syntax error patterns
# Based on the 9 patterns identified in the design document
# ============================================================================

# Pattern classification based on error signatures
function Get-ErrorPattern {
    param(
        [string]$FilePath,
        [array]$Errors
    )
    
    if ($Errors.Count -eq 0) {
        return "PASS"
    }
    
    # Convert errors to strings for pattern matching
    $errorMessages = $Errors | ForEach-Object { "$($_.Extent.StartLineNumber): $($_.Message)" }
    $allErrors = $errorMessages -join " | "
    
    # Pattern A: Line 44 "Missing closing ')'" + Line 47 "Unexpected token 'try'"
    if ($allErrors -match "44.*Missing closing.*\)" -and $allErrors -match "47.*Unexpected token.*try") {
        return "PatternA"
    }
    
    # Pattern B: Line 30 "Missing closing ')'" + Line 32 "Unexpected token 'Write-Host'"
    if ($allErrors -match "30.*Missing closing.*\)" -and $allErrors -match "32.*Unexpected token.*Write-Host") {
        return "PatternB"
    }
    
    # Pattern C: Line 29 "Missing closing ')'" + Line 31 "Unexpected token '$results'"
    if ($allErrors -match "29.*Missing closing.*\)" -and $allErrors -match "31.*Unexpected token.*results") {
        return "PatternC"
    }
    
    # Pattern D: Two PropertiesToLoad errors + BH export string error (lines 20, 22, 134, 136, 173+)
    if ($allErrors -match "20.*Missing closing.*\)" -and $allErrors -match "22.*Unexpected token" -and 
        $allErrors -match "134.*Missing closing.*\)" -and $allErrors -match "136.*Unexpected token" -and
        $allErrors -match "17[3-9].*") {
        return "PatternD"
    }
    
    # Pattern E: Only BH export string error (line 161+ "Unexpected token 'AD'")
    if ($allErrors -match "16[1-9].*Unexpected token.*AD" -or $allErrors -match "17[0-9].*string.*terminator") {
        return "PatternE"
    }
    
    # Pattern F: TMGMT line 46 "Unexpected token '}'"
    if ($FilePath -match "TMGMT" -and $allErrors -match "46.*Unexpected token.*}") {
        return "PatternF"
    }
    
    # Pattern G: TRST line 152 "Catch block must be the last catch block" + BH export error
    if ($FilePath -match "TRST" -and $allErrors -match "152.*Catch block must be the last") {
        return "PatternG"
    }
    
    # Pattern H: DC line 213+ "Unexpected token '`nSummary:'"
    if ($FilePath -match "DC-" -and $allErrors -match "21[3-9].*Unexpected token.*nSummary") {
        return "PatternH"
    }
    
    # Pattern I: GPO-051 regex hashtable + BH export errors
    if ($FilePath -match "GPO-051") {
        return "PatternI"
    }
    
    # If no specific pattern matches, classify as Unknown for further analysis
    return "Unknown"
}

# Initialize tracking structure
$scanResults = @{
    TotalScanned = 0
    TotalPassing = 0
    TotalFailing = 0
    ByPattern = @{
        PASS = @{ Count=0; Files=@() }
        PatternA = @{ Count=0; Files=@() }
        PatternB = @{ Count=0; Files=@() }
        PatternC = @{ Count=0; Files=@() }
        PatternD = @{ Count=0; Files=@() }
        PatternE = @{ Count=0; Files=@() }
        PatternF = @{ Count=0; Files=@() }
        PatternG = @{ Count=0; Files=@() }
        PatternH = @{ Count=0; Files=@() }
        PatternI = @{ Count=0; Files=@() }
        Unknown = @{ Count=0; Files=@() }
    }
    DetailedErrors = @()
}

Write-Host "=== AD Suite Syntax Fix - Phase 1: Pattern Scanner ===" -ForegroundColor Cyan
Write-Host "Scanning all adsi.ps1 files for syntax error patterns..." -ForegroundColor Yellow
Write-Host ""

# Find all adsi.ps1 files in the workspace
$adsiFiles = Get-ChildItem -Path "." -Recurse -Filter "adsi.ps1" -File | Where-Object { $_.FullName -notmatch "ad-suite-web" }

Write-Host "Found $($adsiFiles.Count) adsi.ps1 files to scan" -ForegroundColor Green
Write-Host ""

# Scan each file
foreach ($file in $adsiFiles) {
    $scanResults.TotalScanned++
    
    Write-Host "Scanning: $($file.FullName)" -ForegroundColor Gray
    
    try {
        # Parse the file using PowerShell AST
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$errors)
        
        # Classify the pattern
        $pattern = Get-ErrorPattern -FilePath $file.FullName -Errors $errors
        
        # Update counters
        $scanResults.ByPattern[$pattern].Count++
        $scanResults.ByPattern[$pattern].Files += $file.FullName
        
        if ($pattern -eq "PASS") {
            $scanResults.TotalPassing++
            Write-Host "  ✓ PASS (0 errors)" -ForegroundColor Green
        } else {
            $scanResults.TotalFailing++
            Write-Host "  ✗ $pattern ($($errors.Count) errors)" -ForegroundColor Red
            
            # Store detailed error info for analysis
            $errorDetail = @{
                File = $file.FullName
                Pattern = $pattern
                ErrorCount = $errors.Count
                Errors = $errors | ForEach-Object { 
                    @{
                        Line = $_.Extent.StartLineNumber
                        Message = $_.Message
                    }
                }
            }
            $scanResults.DetailedErrors += $errorDetail
            
            # Show first few errors for immediate feedback
            $errors | Select-Object -First 3 | ForEach-Object {
                Write-Host "    Line $($_.Extent.StartLineNumber): $($_.Message)" -ForegroundColor Yellow
            }
            if ($errors.Count -gt 3) {
                Write-Host "    ... and $($errors.Count - 3) more errors" -ForegroundColor Yellow
            }
        }
    }
    catch {
        Write-Host "  ✗ ERROR: Failed to parse file - $($_.Exception.Message)" -ForegroundColor Red
        $scanResults.ByPattern["Unknown"].Count++
        $scanResults.ByPattern["Unknown"].Files += $file.FullName
        $scanResults.TotalFailing++
    }
    
    Write-Host ""
}

# Generate summary report
Write-Host "=== SCAN RESULTS SUMMARY ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total Files Scanned: $($scanResults.TotalScanned)" -ForegroundColor White
Write-Host "Passing (0 errors): $($scanResults.TotalPassing)" -ForegroundColor Green
Write-Host "Failing (has errors): $($scanResults.TotalFailing)" -ForegroundColor Red
Write-Host ""

Write-Host "Pattern Breakdown:" -ForegroundColor White
foreach ($patternName in $scanResults.ByPattern.Keys | Sort-Object) {
    $pattern = $scanResults.ByPattern[$patternName]
    if ($pattern.Count -gt 0) {
        $color = if ($patternName -eq "PASS") { "Green" } else { "Red" }
        Write-Host "  $patternName`: $($pattern.Count) files" -ForegroundColor $color
    }
}

Write-Host ""

# Save detailed results to JSON for further analysis
$outputPath = "phase1-scan-results.json"
$scanResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputPath -Encoding UTF8
Write-Host "Detailed results saved to: $outputPath" -ForegroundColor Green

# Show some example files for each pattern (for verification)
Write-Host ""
Write-Host "=== PATTERN EXAMPLES ===" -ForegroundColor Cyan
foreach ($patternName in @("PatternA", "PatternB", "PatternC", "PatternD", "PatternE", "PatternF", "PatternG", "PatternH", "PatternI", "Unknown")) {
    $pattern = $scanResults.ByPattern[$patternName]
    if ($pattern.Count -gt 0) {
        Write-Host ""
        Write-Host "$patternName ($($pattern.Count) files):" -ForegroundColor Yellow
        $pattern.Files | Select-Object -First 3 | ForEach-Object {
            Write-Host "  $_" -ForegroundColor Gray
        }
        if ($pattern.Count -gt 3) {
            Write-Host "  ... and $($pattern.Count - 3) more files" -ForegroundColor Gray
        }
    }
}

Write-Host ""
Write-Host "Phase 1 scan complete!" -ForegroundColor Green