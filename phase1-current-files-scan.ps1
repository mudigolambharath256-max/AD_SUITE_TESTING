# Phase 1: Pattern Identification Scanner - Current Files Only
# Scans all adsi.ps1 files excluding backup directories

param(
    [string]$SuiteRoot = ".",
    [string]$OutputFile = "phase1-current-pattern-results.json"
)

# Pattern definitions based on error signatures
$ErrorPatterns = @{
    'A' = @{
        Name = 'Pattern A'
        Description = 'Line 44 "Missing closing )" + Line 47 "Unexpected token try"'
    }
    'B' = @{
        Name = 'Pattern B'
        Description = 'Line 30 "Missing closing )" + Line 32 "Unexpected token Write-Host"'
    }
    'C' = @{
        Name = 'Pattern C'
        Description = 'Line 29 "Missing closing )" + Line 31 "Unexpected token $results"'
    }
    'D' = @{
        Name = 'Pattern D'
        Description = 'Two PropertiesToLoad errors + BH export string error'
    }
    'E' = @{
        Name = 'Pattern E'
        Description = 'Only BH export string error'
    }
    'F' = @{
        Name = 'Pattern F'
        Description = 'TMGMT line 46 "Unexpected token }"'
    }
    'G' = @{
        Name = 'Pattern G'
        Description = 'TRST line 152 "Catch block must be the last catch block" + BH export error'
    }
    'H' = @{
        Name = 'Pattern H'
        Description = 'DC line 213+ "Unexpected token nSummary:"'
    }
    'I' = @{
        Name = 'Pattern I'
        Description = 'GPO-051 regex hashtable + BH export errors'
    }
}

function Test-PowerShellSyntax {
    param([string]$FilePath)
    
    try {
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($FilePath, [ref]$null, [ref]$errors)
        
        $result = @{
            HasErrors = $errors.Count -gt 0
            ErrorCount = $errors.Count
            Errors = @()
        }
        
        if ($errors) {
            foreach ($error in $errors) {
                $result.Errors += @{
                    Line = $error.Extent.StartLineNumber
                    Column = $error.Extent.StartColumnNumber
                    Message = $error.Message
                    ErrorId = $error.ErrorId
                }
            }
        }
        
        return $result
    }
    catch {
        return @{
            HasErrors = $true
            ErrorCount = 1
            Errors = @(@{
                Line = 0
                Column = 0
                Message = "Failed to parse file: $($_.Exception.Message)"
                ErrorId = "ParseException"
            })
        }
    }
}

function Get-PatternMatch {
    param(
        [array]$Errors,
        [string]$FilePath
    )
    
    $fileName = Split-Path $FilePath -Leaf
    $parentDir = Split-Path (Split-Path $FilePath -Parent) -Leaf
    
    # Pattern A: Line 44 "Missing closing ')'" + Line 47 "Unexpected token 'try'"
    if (($Errors | Where-Object { $_.Line -eq 44 -and $_.Message -like "*Missing closing*)*" }) -and
        ($Errors | Where-Object { $_.Line -eq 47 -and $_.Message -like "*Unexpected token*try*" })) {
        return 'A'
    }
    
    # Pattern B: Line 30 "Missing closing ')'" + Line 32 "Unexpected token 'Write-Host'"
    if (($Errors | Where-Object { $_.Line -eq 30 -and $_.Message -like "*Missing closing*)*" }) -and
        ($Errors | Where-Object { $_.Line -eq 32 -and $_.Message -like "*Unexpected token*Write-Host*" })) {
        return 'B'
    }
    
    # Pattern C: Line 29 "Missing closing ')'" + Line 31 "Unexpected token '$results'"
    if (($Errors | Where-Object { $_.Line -eq 29 -and $_.Message -like "*Missing closing*)*" }) -and
        ($Errors | Where-Object { $_.Line -eq 31 -and $_.Message -like "*Unexpected token*results*" })) {
        return 'C'
    }
    
    # Pattern D: Two PropertiesToLoad errors + BH export string error
    $line20Error = $Errors | Where-Object { $_.Line -eq 20 -and $_.Message -like "*Missing closing*)*" }
    $line22Error = $Errors | Where-Object { $_.Line -eq 22 -and $_.Message -like "*Unexpected token*" }
    $line134Error = $Errors | Where-Object { $_.Line -eq 134 -and $_.Message -like "*Missing closing*)*" }
    $line136Error = $Errors | Where-Object { $_.Line -eq 136 -and $_.Message -like "*Unexpected token*" }
    $stringTermError = $Errors | Where-Object { $_.Line -ge 173 -and $_.Message -like "*string is missing the terminator*" }
    
    if ($line20Error -and $line22Error -and $line134Error -and $line136Error -and $stringTermError) {
        return 'D'
    }
    
    # Pattern E: Only BH export string error
    if (($Errors | Where-Object { $_.Line -ge 161 -and $_.Message -like "*Unexpected token*AD*" }) -and
        -not ($line20Error -or $line134Error)) {
        return 'E'
    }
    
    # Pattern F: TMGMT line 46 "Unexpected token '}'"
    if (($parentDir -like "*TMGMT*") -and
        ($Errors | Where-Object { $_.Line -eq 46 -and $_.Message -like "*Unexpected token*}*" })) {
        return 'F'
    }
    
    # Pattern G: TRST line 152 "Catch block must be the last catch block"
    if (($parentDir -like "*TRST*") -and
        ($Errors | Where-Object { $_.Line -eq 152 -and $_.Message -like "*Catch block must be the last*" })) {
        return 'G'
    }
    
    # Pattern H: DC line 213+ "Unexpected token '`nSummary:'"
    if (($parentDir -like "*DC-*") -and
        ($Errors | Where-Object { $_.Line -ge 213 -and $_.Message -like "*Unexpected token*Summary*" })) {
        return 'H'
    }
    
    # Pattern I: GPO-051 regex hashtable + BH export errors
    if (($parentDir -like "*GPO-051*") -and
        ($Errors | Where-Object { $_.Message -like "*string is missing the terminator*" }) -and
        ($Errors | Where-Object { $_.Message -like "*hash literal*" })) {
        return 'I'
    }
    
    # If has errors but doesn't match any pattern, classify as Unknown
    if ($Errors.Count -gt 0) {
        return 'Unknown'
    }
    
    return 'PASS'
}

# Initialize results
$results = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    SuiteRoot = (Resolve-Path $SuiteRoot).Path
    Statistics = @{
        TotalScanned = 0
        TotalPassing = 0
        TotalFailing = 0
        ByPattern = @{}
    }
    Files = @{}
    PatternSummary = @{}
}

# Initialize pattern counters
foreach ($pattern in $ErrorPatterns.Keys) {
    $results.Statistics.ByPattern[$pattern] = 0
    $results.PatternSummary[$pattern] = @{
        Name = $ErrorPatterns[$pattern].Name
        Description = $ErrorPatterns[$pattern].Description
        Files = @()
    }
}
$results.Statistics.ByPattern['Unknown'] = 0
$results.Statistics.ByPattern['PASS'] = 0
$results.PatternSummary['Unknown'] = @{
    Name = 'Unknown Pattern'
    Description = 'Files with errors that do not match any known pattern'
    Files = @()
}
$results.PatternSummary['PASS'] = @{
    Name = 'Passing Files'
    Description = 'Files with no syntax errors'
    Files = @()
}

Write-Host "=== AD Suite Syntax Pattern Scanner - Current Files Only ===" -ForegroundColor Yellow
Write-Host "Scanning all adsi.ps1 files in: $SuiteRoot (excluding backups)" -ForegroundColor White
Write-Host ""

# Find all adsi.ps1 files, excluding backup directories
$adsiFiles = Get-ChildItem -Path $SuiteRoot -Recurse -Filter "adsi.ps1" | 
    Where-Object { $_.FullName -notlike "*backup*" } | 
    Sort-Object FullName

Write-Host "Found $($adsiFiles.Count) current adsi.ps1 files (excluding backups)" -ForegroundColor Cyan
Write-Host ""

foreach ($file in $adsiFiles) {
    $results.Statistics.TotalScanned++
    $relativePath = $file.FullName -replace [regex]::Escape((Get-Item $SuiteRoot).FullName), ''
    $relativePath = $relativePath.TrimStart('\')
    
    Write-Host "Scanning: $relativePath" -ForegroundColor Gray
    
    # Parse the file
    $parseResult = Test-PowerShellSyntax -FilePath $file.FullName
    
    # Determine pattern
    $pattern = Get-PatternMatch -Errors $parseResult.Errors -FilePath $file.FullName
    
    # Store results
    $fileResult = @{
        Path = $relativePath
        FullPath = $file.FullName
        HasErrors = $parseResult.HasErrors
        ErrorCount = $parseResult.ErrorCount
        Pattern = $pattern
        Errors = $parseResult.Errors
        Category = Split-Path (Split-Path $file.FullName -Parent) -Leaf
        CheckName = Split-Path $file.Directory -Leaf
    }
    
    $results.Files[$relativePath] = $fileResult
    $results.Statistics.ByPattern[$pattern]++
    $results.PatternSummary[$pattern].Files += $relativePath
    
    if ($parseResult.HasErrors) {
        $results.Statistics.TotalFailing++
        Write-Host "  → Pattern $pattern ($($parseResult.ErrorCount) errors)" -ForegroundColor Red
        
        # Show first few errors for context
        $firstErrors = $parseResult.Errors | Select-Object -First 3
        foreach ($error in $firstErrors) {
            Write-Host "    Line $($error.Line): $($error.Message)" -ForegroundColor DarkRed
        }
        if ($parseResult.ErrorCount -gt 3) {
            Write-Host "    ... and $($parseResult.ErrorCount - 3) more errors" -ForegroundColor DarkRed
        }
    } else {
        $results.Statistics.TotalPassing++
        Write-Host "  → PASS (no errors)" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "=== SCAN COMPLETE ===" -ForegroundColor Yellow
Write-Host "Total current files scanned: $($results.Statistics.TotalScanned)" -ForegroundColor White
Write-Host "Passing files: $($results.Statistics.TotalPassing)" -ForegroundColor Green
Write-Host "Failing files: $($results.Statistics.TotalFailing)" -ForegroundColor Red
Write-Host ""

Write-Host "Pattern Distribution:" -ForegroundColor Cyan
foreach ($pattern in ($ErrorPatterns.Keys + @('Unknown', 'PASS')) | Sort-Object) {
    $count = $results.Statistics.ByPattern[$pattern]
    if ($count -gt 0) {
        $color = if ($pattern -eq 'PASS') { 'Green' } elseif ($pattern -eq 'Unknown') { 'Yellow' } else { 'Red' }
        Write-Host "  Pattern $pattern`: $count files" -ForegroundColor $color
    }
}

# Save results to JSON
$outputPath = Join-Path $SuiteRoot $OutputFile
$results | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputPath -Encoding UTF8

Write-Host ""
Write-Host "Results saved to: $outputPath" -ForegroundColor Green

# Display pattern details
Write-Host ""
Write-Host "=== PATTERN DETAILS ===" -ForegroundColor Yellow
foreach ($pattern in ($ErrorPatterns.Keys + @('Unknown')) | Sort-Object) {
    $count = $results.Statistics.ByPattern[$pattern]
    if ($count -gt 0) {
        Write-Host ""
        Write-Host "Pattern $pattern - $($results.PatternSummary[$pattern].Name) ($count files):" -ForegroundColor Cyan
        Write-Host "  $($results.PatternSummary[$pattern].Description)" -ForegroundColor White
        
        # Show all files for current scan
        foreach ($file in $results.PatternSummary[$pattern].Files) {
            Write-Host "    $file" -ForegroundColor Gray
        }
    }
}

Write-Host ""
Write-Host "Current files pattern classification complete!" -ForegroundColor Green