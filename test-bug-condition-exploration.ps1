# Bug Condition Exploration Test - Property 1: Fault Condition
# CRITICAL: This test MUST FAIL on unfixed code - failure confirms the bug exists
# DO NOT attempt to fix the test or the code when it fails
# NOTE: This test encodes the expected behavior - it will validate the fix when it passes after implementation

param(
    [string]$SuiteRoot = "."
)

Write-Host "=== Bug Condition Exploration Test ===" -ForegroundColor Yellow
Write-Host "Testing Property 1: Fault Condition - PowerShell Script Syntax Validation" -ForegroundColor Yellow
Write-Host "GOAL: Surface counterexamples that demonstrate syntax errors exist in 515 scripts" -ForegroundColor Yellow
Write-Host ""

# Function to check if a script file has the bug condition
function Test-BugCondition {
    param([string]$ScriptPath)
    
    if (-not (Test-Path $ScriptPath)) {
        return $false
    }
    
    if ((Get-Item $ScriptPath).Name -ne 'adsi.ps1') {
        return $false
    }
    
    $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$null, [ref]$errors)
    
    if ($errors.Count -eq 0) {
        return $false
    }
    
    # Check for specific error patterns that indicate our bug conditions
    $hasBugPattern = $errors | Where-Object {
        $_.Message -match "Missing closing '\)' in expression" -or
        $_.Message -match "The string is missing the terminator" -or
        $_.Message -match "Unexpected token" -or
        $_.Message -match "Catch block must be the last"
    }
    
    return ($hasBugPattern.Count -gt 0)
}

# Function to identify error pattern
function Get-ErrorPattern {
    param([string]$ScriptPath)
    
    $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$null, [ref]$errors)
    
    if ($errors.Count -eq 0) {
        return "PASS"
    }
    
    $firstError = $errors[0]
    $line = $firstError.Extent.StartLineNumber
    $message = $firstError.Message
    
    # Pattern classification based on error signatures from xxxmain.md
    if ($message -match "Missing closing '\)' in expression") {
        if ($line -eq 44 -and $errors.Count -gt 1 -and $errors[1].Message -match "Unexpected token 'try'") {
            return "Pattern A"
        } elseif ($line -eq 30 -and $errors.Count -gt 1 -and $errors[1].Message -match "Unexpected token 'Write-Host'") {
            return "Pattern B"
        } elseif ($line -eq 29 -and $errors.Count -gt 1 -and $errors[1].Message -match "Unexpected token '\$results'") {
            return "Pattern C"
        } elseif ($errors.Count -ge 4) {
            # Check for Pattern D (two PropertiesToLoad + BH export)
            $hasMultiplePropertiesToLoad = ($errors | Where-Object { $_.Message -match "Missing closing '\)'" }).Count -ge 2
            $hasBHExportError = $errors | Where-Object { $_.Message -match "Unexpected token 'AD'" -or $_.Message -match "string is missing the terminator" }
            if ($hasMultiplePropertiesToLoad -and $hasBHExportError) {
                return "Pattern D"
            }
        }
    }
    
    if ($message -match "Unexpected token 'AD'" -or $message -match "string is missing the terminator") {
        return "Pattern E"
    }
    
    if ($line -eq 46 -and $message -match "Unexpected token '}'") {
        return "Pattern F"
    }
    
    if ($message -match "Catch block must be the last catch block") {
        return "Pattern G"
    }
    
    if ($message -match "Unexpected token '`nSummary:'") {
        return "Pattern H"
    }
    
    # GPO-051 specific pattern
    if ($ScriptPath -match "GPO-051" -and ($message -match "regex" -or $message -match "hash literal")) {
        return "Pattern I"
    }
    
    return "Unknown Pattern"
}

# Scan all adsi.ps1 files
Write-Host "Scanning all adsi.ps1 files in $SuiteRoot..." -ForegroundColor Cyan

$results = @{
    TotalScanned = 0
    BuggyScripts = 0
    PassingScripts = 0
    ByPattern = @{}
    CounterExamples = @()
}

if (-not (Test-Path $SuiteRoot)) {
    Write-Host "ERROR: Suite root directory '$SuiteRoot' not found!" -ForegroundColor Red
    exit 1
}

Get-ChildItem $SuiteRoot -Recurse -Filter 'adsi.ps1' | ForEach-Object {
    $results.TotalScanned++
    $scriptPath = $_.FullName
    $relativePath = $scriptPath -replace [regex]::Escape((Get-Item $SuiteRoot).FullName), ''
    
    if (Test-BugCondition $scriptPath) {
        $results.BuggyScripts++
        $pattern = Get-ErrorPattern $scriptPath
        
        if (-not $results.ByPattern.ContainsKey($pattern)) {
            $results.ByPattern[$pattern] = @()
        }
        $results.ByPattern[$pattern] += $relativePath
        
        # Collect detailed error info for counterexamples
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$errors)
        
        $results.CounterExamples += [PSCustomObject]@{
            File = $relativePath
            Pattern = $pattern
            ErrorCount = $errors.Count
            FirstError = "Line $($errors[0].Extent.StartLineNumber): $($errors[0].Message)"
        }
        
        Write-Host "FAIL: $relativePath [$pattern] - $($errors.Count) errors" -ForegroundColor Red
    } else {
        $results.PassingScripts++
        Write-Host "PASS: $relativePath" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "=== TEST RESULTS ===" -ForegroundColor Yellow
Write-Host "Total scripts scanned: $($results.TotalScanned)" -ForegroundColor White
Write-Host "Scripts with bug condition: $($results.BuggyScripts)" -ForegroundColor Red
Write-Host "Scripts passing: $($results.PassingScripts)" -ForegroundColor Green
Write-Host ""

Write-Host "=== PATTERN BREAKDOWN ===" -ForegroundColor Yellow
foreach ($pattern in $results.ByPattern.Keys | Sort-Object) {
    $count = $results.ByPattern[$pattern].Count
    Write-Host "$pattern`: $count files" -ForegroundColor White
}

Write-Host ""
Write-Host "=== COUNTEREXAMPLES (First 10) ===" -ForegroundColor Yellow
$results.CounterExamples | Select-Object -First 10 | Format-Table -AutoSize

Write-Host ""
Write-Host "=== EXPECTED SPECIFIC COUNTEREXAMPLES ===" -ForegroundColor Yellow

# Check for specific expected counterexamples from the design document
$expectedExamples = @(
    @{ Pattern = "Pattern A"; File = "*ACC-002*"; ExpectedError = "Missing closing ')' in expression" }
    @{ Pattern = "Pattern D"; File = "*AUTH-031*"; ExpectedError = "Missing closing ')'" }
    @{ Pattern = "Pattern F"; File = "*TMGMT-001*"; ExpectedError = "Unexpected token '}'" }
    @{ Pattern = "Pattern G"; File = "*TRST-005*"; ExpectedError = "Catch block must be the last catch block" }
    @{ Pattern = "Pattern H"; File = "*DC-001*"; ExpectedError = "Unexpected token '`nSummary:'" }
)

foreach ($expected in $expectedExamples) {
    $found = $results.CounterExamples | Where-Object { 
        $_.File -like $expected.File -and 
        $_.Pattern -eq $expected.Pattern -and
        $_.FirstError -match [regex]::Escape($expected.ExpectedError.Split(':')[0])
    }
    
    if ($found) {
        Write-Host "✓ Found expected $($expected.Pattern) in $($found.File)" -ForegroundColor Green
    } else {
        Write-Host "✗ Missing expected $($expected.Pattern) for $($expected.File)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== TEST CONCLUSION ===" -ForegroundColor Yellow

if ($results.BuggyScripts -gt 0) {
    Write-Host "TEST RESULT: FAIL (as expected)" -ForegroundColor Red
    Write-Host "This is CORRECT - the test failure confirms the bug exists!" -ForegroundColor Green
    Write-Host "Found $($results.BuggyScripts) scripts with syntax errors across $($results.ByPattern.Keys.Count) patterns" -ForegroundColor White
    Write-Host ""
    Write-Host "Bug condition exploration SUCCESSFUL - counterexamples documented" -ForegroundColor Green
    exit 0  # Success - we found the bugs as expected
} else {
    Write-Host "TEST RESULT: UNEXPECTED PASS" -ForegroundColor Red
    Write-Host "ERROR: No syntax errors found - this suggests the code is already fixed!" -ForegroundColor Red
    Write-Host "Expected to find ~515 failing scripts based on test results" -ForegroundColor Red
    exit 1  # Failure - we expected to find bugs but didn't
}