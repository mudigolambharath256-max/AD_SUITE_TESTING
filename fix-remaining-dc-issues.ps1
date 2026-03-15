#!/usr/bin/env powershell
# Fix Remaining 10 Domain Controller Files with Parse Errors
# Task 3.6: Address the final syntax issues to achieve 100% success rate

Write-Host "=== Fixing Remaining DC Parse Errors ===" -ForegroundColor Cyan
Write-Host "Targeting 10 specific files with syntax issues" -ForegroundColor Yellow
Write-Host ""

# List of files that need fixing based on validation report
$failedFiles = @(
    "Domain_Controllers\DC-001_Domain_Controllers_Inventory\adsi.ps1",
    "Domain_Controllers\DC-012_DCs_with_Expiring_Certificates\DC-036_DCs_with_Expiring_Certificates\adsi.ps1",
    "Domain_Controllers\DC-013_DCs_Replication_Failures\DC-037_DCs_Replication_Failures\adsi.ps1",
    "Domain_Controllers\DC-014_DCs_Null_Session_Enabled\DC-038_DCs_Null_Session_Enabled\adsi.ps1",
    "Domain_Controllers\DC-015_DCs_with_Print_Spooler_Running\DC-039_DCs_with_Print_Spooler_Running\adsi.ps1",
    "Domain_Controllers\DC-020_DCs_with_Excessive_Open_Ports\adsi.ps1",
    "Domain_Controllers\DC-028_DCs_with_Old_DSRM_Password\adsi.ps1",
    "Domain_Controllers\DC-030_DCs_with_Disabled_Security_Event_Log\adsi.ps1",
    "Domain_Controllers\DC-032_DCs_with_PowerShell_v2_Enabled\adsi.ps1",
    "Domain_Controllers\DC-036_DCs_with_Insecure_Screensaver_Policy\adsi.ps1"
)

$fixResults = @{
    TotalAttempted = 0
    TotalFixed = 0
    TotalStillFailed = 0
    FixedFiles = @()
    StillFailedFiles = @()
}

foreach ($filePath in $failedFiles) {
    $fixResults.TotalAttempted++
    Write-Host "[$($fixResults.TotalAttempted)/10] Fixing: $filePath" -ForegroundColor Gray
    
    if (-not (Test-Path $filePath)) {
        Write-Host "  ⚠️  File not found: $filePath" -ForegroundColor Yellow
        continue
    }
    
    try {
        # Read the file content
        $content = Get-Content -Path $filePath -Raw
        $originalContent = $content
        $wasFixed = $false
        
        # Fix 1: Corrupted PropertiesToLoad lines (common pattern in DC-012, DC-013, DC-014, DC-015)
        # Look for broken PropertiesToLoad.Add( lines that got corrupted
        if ($content -match '\[void\]\$searcher\.PropertiesToLoad\.Add\(# Check:') {
            Write-Host "    Fixing corrupted PropertiesToLoad line..." -ForegroundColor Yellow
            
            # Extract the check ID and properties from the corrupted line
            if ($content -match '# ID: (DC-\d+)') {
                $checkId = $matches[1]
                
                # Replace the corrupted line with a proper PropertiesToLoad block
                $content = $content -replace '\[void\]\$searcher\.PropertiesToLoad\.Add\(# Check:.*?(?=\n\n|\n#|\nWrite-Host|\ntry|\n\$results)', ''
                
                # Add proper PropertiesToLoad after the Clear() line
                $content = $content -replace '(\$searcher\.PropertiesToLoad\.Clear\(\)\n)', "`$1@('name', 'distinguishedName', 'dNSHostName', 'operatingSystem', 'userAccountControl', 'objectSid') | ForEach-Object { [void]`$searcher.PropertiesToLoad.Add(`$_) }`n"
                
                $wasFixed = $true
            }
        }
        
        # Fix 2: Missing try block (DC-001)
        if ($content -match '} catch \{' -and $content -notmatch 'try \{') {
            Write-Host "    Adding missing try block..." -ForegroundColor Yellow
            
            # Find the catch block and add a try block before the main logic
            $content = $content -replace '(\$searcher = \[ADSISearcher\])', "try {`n`$1"
            $wasFixed = $true
        }
        
        # Fix 3: Incomplete try blocks (DC-028, DC-030, DC-036)
        if ($content -match 'The Try statement is missing its Catch or Finally block') {
            Write-Host "    Fixing incomplete try blocks..." -ForegroundColor Yellow
            
            # Look for try blocks without proper catch/finally
            $lines = $content -split "`n"
            $fixedLines = @()
            $inTryBlock = $false
            $braceCount = 0
            
            for ($i = 0; $i -lt $lines.Length; $i++) {
                $line = $lines[$i]
                
                if ($line -match '^\s*try\s*\{') {
                    $inTryBlock = $true
                    $braceCount = 1
                    $fixedLines += $line
                } elseif ($inTryBlock) {
                    # Count braces to find the end of the try block
                    $braceCount += ($line.ToCharArray() | Where-Object { $_ -eq '{' }).Count
                    $braceCount -= ($line.ToCharArray() | Where-Object { $_ -eq '}' }).Count
                    
                    $fixedLines += $line
                    
                    if ($braceCount -eq 0) {
                        # End of try block - check if next line is catch or finally
                        if ($i + 1 -lt $lines.Length -and $lines[$i + 1] -notmatch '^\s*(catch|finally)') {
                            # Add a catch block
                            $fixedLines += "} catch {"
                            $fixedLines += "    Write-Error `"Error in $checkId`: `$_`""
                        }
                        $inTryBlock = $false
                    }
                } else {
                    $fixedLines += $line
                }
            }
            
            $content = $fixedLines -join "`n"
            $wasFixed = $true
        }
        
        # Fix 4: Pipeline expression issues (DC-020)
        if ($content -match 'Expressions are only allowed as the first element of a pipeline') {
            Write-Host "    Fixing pipeline expression..." -ForegroundColor Yellow
            
            # Look for malformed pipeline expressions and fix them
            $content = $content -replace '\|\s*\|\s*', '| '
            $content = $content -replace '\|\s*([^|]+)\s*\|', '| $1 |'
            
            $wasFixed = $true
        }
        
        # Fix 5: Missing parameter arguments (DC-032)
        if ($content -match 'Missing argument in parameter list') {
            Write-Host "    Fixing missing parameter arguments..." -ForegroundColor Yellow
            
            # Look for function calls with missing arguments
            $content = $content -replace '(\w+)\(\s*,', '$1($null,'
            $content = $content -replace ',\s*\)', ', $null)'
            
            $wasFixed = $true
        }
        
        # Fix 6: Unexpected tokens in expressions (DC-030, DC-036)
        if ($content -match 'Unexpected token.*in expression or statement') {
            Write-Host "    Fixing unexpected tokens..." -ForegroundColor Yellow
            
            # Look for common issues with string concatenation and expressions
            $content = $content -replace '(\w+)\s+(\w+)\s*\}', '$1_$2 }'
            $content = $content -replace '"([^"]*)\s+([^"]*)"', '"$1_$2"'
            
            $wasFixed = $true
        }
        
        # Fix 7: Missing closing braces (general fix)
        if ($content -match 'Missing closing.*\}') {
            Write-Host "    Balancing braces..." -ForegroundColor Yellow
            
            # Count opening and closing braces
            $openBraces = ($content.ToCharArray() | Where-Object { $_ -eq '{' }).Count
            $closeBraces = ($content.ToCharArray() | Where-Object { $_ -eq '}' }).Count
            
            if ($openBraces -gt $closeBraces) {
                $missingBraces = $openBraces - $closeBraces
                $content += "`n" + ("}" * $missingBraces)
                $wasFixed = $true
            }
        }
        
        # Write the fixed content back to file if changes were made
        if ($wasFixed -and $content -ne $originalContent) {
            Set-Content -Path $filePath -Value $content -Encoding UTF8
            Write-Host "    ✓ Applied fixes" -ForegroundColor Green
        }
        
        # Validate the fix by parsing the file
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$null, [ref]$errors)
        
        if ($errors.Count -eq 0) {
            $fixResults.TotalFixed++
            $fixResults.FixedFiles += $filePath
            Write-Host "    ✅ FIXED - File now parses successfully" -ForegroundColor Green
        } else {
            $fixResults.TotalStillFailed++
            $fixResults.StillFailedFiles += [PSCustomObject]@{
                File = $filePath
                ErrorCount = $errors.Count
                FirstError = "Line $($errors[0].Extent.StartLineNumber): $($errors[0].Message)"
            }
            Write-Host "    ❌ STILL FAILED - $($errors.Count) errors remain" -ForegroundColor Red
            Write-Host "      First Error: Line $($errors[0].Extent.StartLineNumber) - $($errors[0].Message)" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "    ❌ ERROR processing file: $($_.Exception.Message)" -ForegroundColor Red
        $fixResults.TotalStillFailed++
        $fixResults.StillFailedFiles += [PSCustomObject]@{
            File = $filePath
            ErrorCount = 1
            FirstError = "Processing error: $($_.Exception.Message)"
        }
    }
    
    Write-Host ""
}

# Summary
Write-Host "=== FIX SUMMARY ===" -ForegroundColor Cyan
Write-Host "Files Attempted: $($fixResults.TotalAttempted)" -ForegroundColor White
Write-Host "Files Fixed: $($fixResults.TotalFixed)" -ForegroundColor Green
Write-Host "Files Still Failed: $($fixResults.TotalStillFailed)" -ForegroundColor Red
Write-Host ""

if ($fixResults.TotalFixed -gt 0) {
    Write-Host "SUCCESSFULLY FIXED FILES:" -ForegroundColor Green
    foreach ($file in $fixResults.FixedFiles) {
        Write-Host "  ✅ $file" -ForegroundColor Green
    }
    Write-Host ""
}

if ($fixResults.TotalStillFailed -gt 0) {
    Write-Host "STILL FAILED FILES:" -ForegroundColor Red
    foreach ($failure in $fixResults.StillFailedFiles) {
        Write-Host "  ❌ $($failure.File)" -ForegroundColor Red
        Write-Host "     $($failure.FirstError)" -ForegroundColor Red
    }
    Write-Host ""
}

# Final status
if ($fixResults.TotalStillFailed -eq 0) {
    Write-Host "🎯 SUCCESS: All 10 files have been fixed!" -ForegroundColor Green
    Write-Host "Ready for final validation to achieve 100% success rate" -ForegroundColor Green
} else {
    Write-Host "⚠️  PARTIAL SUCCESS: $($fixResults.TotalFixed) files fixed, $($fixResults.TotalStillFailed) still need attention" -ForegroundColor Yellow
}

Write-Host "=== END DC FIXES ===" -ForegroundColor Cyan