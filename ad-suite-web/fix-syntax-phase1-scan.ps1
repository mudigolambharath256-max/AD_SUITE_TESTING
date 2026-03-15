# ============================================================================
# AD Suite Syntax Fix - Phase 1: Pattern Identification Scanner
# ============================================================================
# Scans all adsi.ps1 files and categorizes them by syntax error patterns
# Based on the 9 patterns identified in the design document
# ============================================================================

param(
    [switch]$Verbose = $false
)

# Initialize tracking structures
$fixTracker = @{
    TotalScanned = 0
    TotalFixed = 0
    ByPattern = @{
        PatternA = @{ Count=0; Files=@() }
        PatternB = @{ Count=0; Files=@() }
        PatternC = @{ Count=0; Files=@() }
        PatternD = @{ Count=0; Files=@() }
        PatternE = @{ Count=0; Files=@() }
        PatternF = @{ Count=0; Files=@() }
        PatternG = @{ Count=0; Files=@() }
        PatternH = @{ Count=0; Files=@() }
        PatternI = @{ Count=0; Files=@() }
        PASS = @{ Count=0; Files=@() }
    }
    ByCategory = @{}
    FailedToFix = @()
}

function Test-PowerShellSyntax {
    param([string]$FilePath)
    
    try {
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($FilePath, [ref]$null, [ref]$errors)
        
        return @{
            HasErrors = $errors.Count -gt 0
            ErrorCount = $errors.Count
            Errors = $errors
            FirstError = if ($errors.Count -gt 0) { 
                @{
                    Line = $errors[0].Extent.StartLineNumber
                    Message = $errors[0].Message
                }
            } else { $null }
        }
    } catch {
        return @{
            HasErrors = $true
            ErrorCount = 1
            Errors = @(@{ Message = "Parse exception: $($_.Exception.Message)" })
            FirstError = @{
                Line = 0
                Message = "Parse exception: $($_.Exception.Message)"
            }
        }
    }
}

function Identify-ErrorPattern {
    param(
        [string]$FilePath,
        [object]$ParseResult
    )
    
    if (-not $ParseResult.HasErrors) {
        return 'PASS'
    }
    
    $content = Get-Content $FilePath -Raw
    $errors = $ParseResult.Errors
    $firstError = $ParseResult.FirstError
    
    # Pattern A: Line 44 "Missing closing ')'" + Line 47 "Unexpected token 'try'"
    if ($errors.Count -ge 2 -and 
        $errors[0].Extent.StartLineNumber -eq 44 -and 
        $errors[0].Message -like "*Missing closing ')' in expression*" -and
        $errors[1].Extent.StartLineNumber -eq 47 -and
        $errors[1].Message -like "*Unexpected token 'try'*") {
        return 'PatternA'
    }
    
    # Pattern B: Line 30 "Missing closing ')'" + Line 32 "Unexpected token 'Write-Host'"
    if ($errors.Count -ge 2 -and 
        $errors[0].Extent.StartLineNumber -eq 30 -and 
        $errors[0].Message -like "*Missing closing ')' in expression*" -and
        $errors[1].Extent.StartLineNumber -eq 32 -and
        $errors[1].Message -like "*Unexpected token 'Write-Host'*") {
        return 'PatternB'
    }
    
    # Pattern C: Line 29 "Missing closing ')'" + Line 31 "Unexpected token '$results'"
    if ($errors.Count -ge 2 -and 
        $errors[0].Extent.StartLineNumber -eq 29 -and 
        $errors[0].Message -like "*Missing closing ')' in expression*" -and
        $errors[1].Extent.StartLineNumber -eq 31 -and
        $errors[1].Message -like "*Unexpected token '\$results'*") {
        return 'PatternC'
    }
    
    # Pattern D: Two PropertiesToLoad errors + BH export string error (lines 20, 22, 134, 136, 173+)
    $propertiesToLoadErrors = $errors | Where-Object { $_.Message -like "*Missing closing ')' in expression*" }
    $bhExportErrors = $errors | Where-Object { $_.Message -like "*string is missing the terminator*" -or $_.Message -like "*Unexpected token*" }
    
    if ($propertiesToLoadErrors.Count -eq 2 -and $bhExportErrors.Count -gt 0) {
        $lines = $propertiesToLoadErrors | ForEach-Object { $_.Extent.StartLineNumber }
        if ($lines -contains 20 -and $lines -contains 22) {
            return 'PatternD'
        }
    }
    
    # Pattern E: Only BH export string error (line 161+ "Unexpected token 'AD'")
    if ($errors.Count -eq 1 -and 
        $firstError.Line -gt 160 -and
        ($firstError.Message -like "*Unexpected token 'AD'*" -or 
         $firstError.Message -like "*string is missing the terminator*")) {
        return 'PatternE'
    }
    
    # Pattern F: TMGMT line 46 "Unexpected token '}'"
    if ($FilePath -like "*TMGMT*" -and
        $firstError.Line -eq 46 -and
        $firstError.Message -like "*Unexpected token '}'*") {
        return 'PatternF'
    }
    
    # Pattern G: TRST line 152 "Catch block must be the last catch block" + BH export error
    if ($FilePath -like "*TRST*" -and
        $errors | Where-Object { $_.Message -like "*Catch block must be the last catch block*" }) {
        return 'PatternG'
    }
    
    # Pattern H: DC line 213+ "Unexpected token '`nSummary:'"
    if ($FilePath -like "*DC-*" -and
        $firstError.Line -gt 210 -and
        $firstError.Message -like "*Unexpected token*Summary*") {
        return 'PatternH'
    }
    
    # Pattern I: GPO-051 regex hashtable + BH export errors
    if ($FilePath -like "*GPO-051*" -and
        ($errors | Where-Object { $_.Message -like "*string is missing the terminator*" -or $_.Message -like "*hash literal*" })) {
        return 'PatternI'
    }
    
    # If no specific pattern matches, classify by general error type
    if ($firstError.Message -like "*Missing closing ')' in expression*") {
        return 'PatternA'  # Default to Pattern A for PropertiesToLoad issues
    }
    
    if ($firstError.Message -like "*string is missing the terminator*") {
        return 'PatternE'  # Default to Pattern E for string terminator issues
    }
    
    # Unknown pattern
    return 'Unknown'
}

# Main scanning logic
Write-Host "=== AD Suite Syntax Fix - Phase 1: Pattern Scanner ===" -ForegroundColor Cyan
Write-Host "Scanning all adsi.ps1 files for syntax error patterns..." -ForegroundColor Yellow
Write-Host ""

# Find all adsi.ps1 files
$adsiFiles = @()
# Look in parent directory for category folders
$parentPath = Split-Path (Get-Location) -Parent
$categories = Get-ChildItem -Path $parentPath -Directory | Where-Object { 
    $_.Name -notmatch '^(ad-suite-web|\.vscode|\.kiro|\.git|backups|node_modules|AD_suiteXXX)' 
}

foreach ($category in $categories) {
    $checks = Get-ChildItem -Path $category.FullName -Directory -ErrorAction SilentlyContinue
    foreach ($check in $checks) {
        $adsiPath = Join-Path $check.FullName "adsi.ps1"
        if (Test-Path $adsiPath) {
            $adsiFiles += $adsiPath
        }
    }
}

Write-Host "Found $($adsiFiles.Count) adsi.ps1 files to scan" -ForegroundColor Green
Write-Host ""

# Process each file
foreach ($filePath in $adsiFiles) {
    $fixTracker.TotalScanned++
    
    # Get category from path
    $relativePath = $filePath -replace [regex]::Escape((Get-Location).Path + "\"), ""
    $category = ($relativePath -split '\\')[0]
    
    if (-not $fixTracker.ByCategory.ContainsKey($category)) {
        $fixTracker.ByCategory[$category] = @{ Pass=0; Fail=0; Files=@() }
    }
    
    # Parse the file
    $parseResult = Test-PowerShellSyntax -FilePath $filePath
    $pattern = Identify-ErrorPattern -FilePath $filePath -ParseResult $parseResult
    
    # Track results
    if (-not $fixTracker.ByPattern.ContainsKey($pattern)) {
        $fixTracker.ByPattern[$pattern] = @{ Count=0; Files=@() }
    }
    $fixTracker.ByPattern[$pattern].Count++
    $fixTracker.ByPattern[$pattern].Files += $relativePath
    
    if ($parseResult.HasErrors) {
        $fixTracker.ByCategory[$category].Fail++
    } else {
        $fixTracker.ByCategory[$category].Pass++
    }
    
    $fixTracker.ByCategory[$category].Files += @{
        Path = $relativePath
        Pattern = $pattern
        ErrorCount = $parseResult.ErrorCount
        FirstError = $parseResult.FirstError
    }
    
    # Verbose output
    if ($Verbose) {
        $status = if ($parseResult.HasErrors) { "FAIL" } else { "PASS" }
        $errorInfo = if ($parseResult.HasErrors) { 
            " - $($parseResult.ErrorCount) errors, Pattern: $pattern, First: Line $($parseResult.FirstError.Line) - $($parseResult.FirstError.Message)" 
        } else { "" }
        Write-Host "  [$status] $relativePath$errorInfo" -ForegroundColor $(if ($parseResult.HasErrors) { "Red" } else { "Green" })
    }
}

# Generate summary report
Write-Host "=== SCAN RESULTS SUMMARY ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total Files Scanned: $($fixTracker.TotalScanned)" -ForegroundColor White
Write-Host "Files with Errors: $(($fixTracker.ByPattern.Keys | Where-Object { $_ -ne 'PASS' } | ForEach-Object { $fixTracker.ByPattern[$_].Count } | Measure-Object -Sum).Sum)" -ForegroundColor Red
Write-Host "Files Passing: $($fixTracker.ByPattern.PASS.Count)" -ForegroundColor Green
Write-Host ""

Write-Host "=== PATTERN BREAKDOWN ===" -ForegroundColor Cyan
foreach ($pattern in @('PatternA', 'PatternB', 'PatternC', 'PatternD', 'PatternE', 'PatternF', 'PatternG', 'PatternH', 'PatternI', 'PASS')) {
    $count = $fixTracker.ByPattern[$pattern].Count
    if ($count -gt 0) {
        $color = if ($pattern -eq 'PASS') { 'Green' } else { 'Yellow' }
        Write-Host "  $pattern`: $count files" -ForegroundColor $color
    }
}
Write-Host ""

Write-Host "=== CATEGORY BREAKDOWN ===" -ForegroundColor Cyan
foreach ($category in ($fixTracker.ByCategory.Keys | Sort-Object)) {
    $stats = $fixTracker.ByCategory[$category]
    $total = $stats.Pass + $stats.Fail
    $passRate = if ($total -gt 0) { [math]::Round(($stats.Pass / $total) * 100, 1) } else { 0 }
    Write-Host "  $category`: $total files ($($stats.Pass) pass, $($stats.Fail) fail) - $passRate% pass rate" -ForegroundColor White
}
Write-Host ""

# Save detailed results to JSON
$reportPath = "phase1-scan-results.json"
$fixTracker | ConvertTo-Json -Depth 10 | Out-File $reportPath -Encoding UTF8
Write-Host "Detailed results saved to: $reportPath" -ForegroundColor Green

# Show sample files for each pattern
Write-Host "=== SAMPLE FILES BY PATTERN ===" -ForegroundColor Cyan
foreach ($pattern in @('PatternA', 'PatternB', 'PatternC', 'PatternD', 'PatternE', 'PatternF', 'PatternG', 'PatternH', 'PatternI')) {
    $files = $fixTracker.ByPattern[$pattern].Files
    if ($files.Count -gt 0) {
        Write-Host "  $pattern ($($files.Count) files):" -ForegroundColor Yellow
        $files | Select-Object -First 3 | ForEach-Object {
            Write-Host "    - $_" -ForegroundColor Gray
        }
        if ($files.Count -gt 3) {
            Write-Host "    ... and $($files.Count - 3) more" -ForegroundColor Gray
        }
        Write-Host ""
    }
}

Write-Host "Phase 1 scan complete!" -ForegroundColor Green