# AD Suite Syntax Fix - Phase 1: Focused Pattern Scanner
# ============================================================================
# Scans adsi.ps1 files in main directories only (excludes backups)
# Based on actual error patterns observed
# ============================================================================

# Pattern classification based on actual error signatures
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
    
    # Pattern F: TMGMT files with missing closing '}' at line 37
    if ($FilePath -match "TMGMT" -and $allErrors -match "37.*Missing closing.*}") {
        return "PatternF"
    }
    
    # Pattern G: TRST files with "Try statement missing Catch or Finally" at line 22 + extra '}' at line 164
    if ($FilePath -match "TRST" -and $allErrors -match "22.*Try statement.*missing.*Catch.*Finally" -and $allErrors -match "164.*Unexpected token.*}") {
        return "PatternG"
    }
    
    # Pattern A: Missing closing ')' in PropertiesToLoad around line 20 + Unexpected token '$results' around line 22
    if ($allErrors -match "20.*Missing closing.*\)" -and $allErrors -match "22.*Unexpected token.*results") {
        return "PatternA"
    }
    
    # Pattern B: Missing closing ')' in PropertiesToLoad around line 30 + other errors
    if ($allErrors -match "30.*Missing closing.*\)" -and $allErrors -match "32.*Unexpected token") {
        return "PatternB"
    }
    
    # Pattern C: Missing closing ')' in PropertiesToLoad around line 29 + Unexpected token '$results' around line 31
    if ($allErrors -match "29.*Missing closing.*\)" -and $allErrors -match "31.*Unexpected token.*results") {
        return "PatternC"
    }
    
    # Pattern I: GPO-051 with string terminator issues
    if ($FilePath -match "GPO-051" -and $allErrors -match "string.*terminator") {
        return "PatternI"
    }
    
    # Pattern D: Multiple PropertiesToLoad errors + BH export issues (complex pattern)
    if (($allErrors -match "Missing closing.*\)" | Measure-Object).Count -ge 2 -and $allErrors -match "17[0-9]") {
        return "PatternD"
    }
    
    # Pattern E: BH export string errors only (line 160+)
    if ($allErrors -match "16[0-9].*string.*terminator" -or $allErrors -match "17[0-9].*Unexpected token") {
        return "PatternE"
    }
    
    # Pattern H: DC files with unclosed strings
    if ($FilePath -match "DC-" -and $allErrors -match "string.*terminator") {
        return "PatternH"
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

Write-Host "=== AD Suite Syntax Fix - Phase 1: Focused Pattern Scanner ===" -ForegroundColor Cyan
Write-Host "Scanning adsi.ps1 files in main directories (excluding backups)..." -ForegroundColor Yellow
Write-Host ""

# Find all adsi.ps1 files in main directories only (exclude backups)
$adsiFiles = Get-ChildItem -Path "." -Recurse -Filter "adsi.ps1" -File | Where-Object { 
    $_.FullName -notmatch "ad-suite-web" -and 
    $_.FullName -notmatch "backups_" -and
    $_.FullName -notmatch "\\backups\\" -and
    $_.FullName -notmatch "backup"
}

Write-Host "Found $($adsiFiles.Count) adsi.ps1 files to scan (excluding backups)" -ForegroundColor Green
Write-Host ""

# Scan each file
foreach ($file in $adsiFiles) {
    $scanResults.TotalScanned++
    
    Write-Host "Scanning: $($file.Name) in $($file.Directory.Name)" -ForegroundColor Gray
    
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
Write-Host "=== FOCUSED SCAN RESULTS SUMMARY ===" -ForegroundColor Cyan
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
$outputPath = "phase1-focused-scan-results.json"
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
        $pattern.Files | Select-Object -First 5 | ForEach-Object {
            $shortPath = $_ -replace ".*\\([^\\]+\\[^\\]+\\[^\\]+)$", '$1'
            Write-Host "  $shortPath" -ForegroundColor Gray
        }
        if ($pattern.Count -gt 5) {
            Write-Host "  ... and $($pattern.Count - 5) more files" -ForegroundColor Gray
        }
    }
}

Write-Host ""
Write-Host "Phase 1 focused scan complete!" -ForegroundColor Green