# Test All AD Suite Scripts
# This script runs all scripts in all categories and captures errors

param(
    [string]$SuiteRoot = "C:\users\vagrant\Desktop\AD_SUITE_TESTING",
    [string]$OutputFile = "script-test-results.txt",
    [switch]$TestADSI,
    [switch]$TestPowerShell,
    [switch]$TestCMD,
    [switch]$TestAll
)

# If no specific engine selected, test all
if (-not $TestADSI -and -not $TestPowerShell -and -not $TestCMD) {
    $TestAll = $true
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$results = @()
$totalScripts = 0
$successCount = 0
$errorCount = 0
$syntaxErrorCount = 0

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "AD Suite Script Testing Tool" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Started: $timestamp" -ForegroundColor Gray
Write-Host "Suite Root: $SuiteRoot" -ForegroundColor Gray
Write-Host ""

# Output header
$header = @"
========================================
AD SUITE SCRIPT TEST RESULTS
========================================
Test Date: $timestamp
Suite Root: $SuiteRoot

"@

$results += $header

# Get all category folders
$categories = Get-ChildItem -Path $SuiteRoot -Directory | Where-Object { 
    $_.Name -notmatch '^(ad-suite-web|backups|\.git|\.vscode|node_modules)' 
}

Write-Host "Found $($categories.Count) categories to test" -ForegroundColor Green
Write-Host ""

foreach ($category in $categories) {
    Write-Host "Testing Category: $($category.Name)" -ForegroundColor Yellow
    $results += "`n========================================`n"
    $results += "CATEGORY: $($category.Name)`n"
    $results += "========================================`n"
    
    # Get all check folders in this category
    $checkFolders = Get-ChildItem -Path $category.FullName -Directory
    
    foreach ($checkFolder in $checkFolders) {
        $checkId = $checkFolder.Name
        Write-Host "  Testing: $checkId" -ForegroundColor Cyan
        
        $results += "`n--- CHECK: $checkId ---`n"
        
        # Test ADSI script
        if ($TestAll -or $TestADSI) {
            $adsiScript = Join-Path $checkFolder.FullName "adsi.ps1"
            if (Test-Path $adsiScript) {
                $totalScripts++
                Write-Host "    [ADSI] Testing..." -NoNewline
                
                try {
                    # First check for syntax errors
                    $syntaxCheck = $null
                    $syntaxErrors = $null
                    $syntaxCheck = [System.Management.Automation.PSParser]::Tokenize((Get-Content $adsiScript -Raw), [ref]$syntaxErrors)
                    
                    if ($syntaxErrors.Count -gt 0) {
                        $syntaxErrorCount++
                        $errorCount++
                        Write-Host " SYNTAX ERROR" -ForegroundColor Red
                        $results += "[ADSI] SYNTAX ERROR`n"
                        foreach ($err in $syntaxErrors) {
                            $results += "  Line $($err.Token.StartLine): $($err.Message)`n"
                        }
                    } else {
                        # Try to run the script with a timeout
                        $job = Start-Job -ScriptBlock {
                            param($scriptPath)
                            & $scriptPath 2>&1
                        } -ArgumentList $adsiScript
                        
                        $completed = Wait-Job $job -Timeout 10
                        
                        if ($completed) {
                            $output = Receive-Job $job
                            $errors = $output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
                            
                            if ($errors.Count -gt 0) {
                                $errorCount++
                                Write-Host " ERROR" -ForegroundColor Red
                                $results += "[ADSI] RUNTIME ERROR`n"
                                foreach ($err in $errors) {
                                    $results += "  $($err.Exception.Message)`n"
                                }
                            } else {
                                $successCount++
                                Write-Host " OK" -ForegroundColor Green
                                $results += "[ADSI] OK`n"
                            }
                        } else {
                            $errorCount++
                            Write-Host " TIMEOUT" -ForegroundColor Yellow
                            $results += "[ADSI] TIMEOUT (>10s)`n"
                        }
                        
                        Remove-Job $job -Force
                    }
                } catch {
                    $errorCount++
                    Write-Host " EXCEPTION" -ForegroundColor Red
                    $results += "[ADSI] EXCEPTION: $($_.Exception.Message)`n"
                }
            }
        }
        
        # Test PowerShell script
        if ($TestAll -or $TestPowerShell) {
            $psScript = Join-Path $checkFolder.FullName "powershell.ps1"
            if (Test-Path $psScript) {
                $totalScripts++
                Write-Host "    [PowerShell] Testing..." -NoNewline
                
                try {
                    # Check for syntax errors
                    $syntaxCheck = $null
                    $syntaxErrors = $null
                    $syntaxCheck = [System.Management.Automation.PSParser]::Tokenize((Get-Content $psScript -Raw), [ref]$syntaxErrors)
                    
                    if ($syntaxErrors.Count -gt 0) {
                        $syntaxErrorCount++
                        $errorCount++
                        Write-Host " SYNTAX ERROR" -ForegroundColor Red
                        $results += "[PowerShell] SYNTAX ERROR`n"
                        foreach ($err in $syntaxErrors) {
                            $results += "  Line $($err.Token.StartLine): $($err.Message)`n"
                        }
                    } else {
                        # Try to run the script with a timeout
                        $job = Start-Job -ScriptBlock {
                            param($scriptPath)
                            & $scriptPath 2>&1
                        } -ArgumentList $psScript
                        
                        $completed = Wait-Job $job -Timeout 10
                        
                        if ($completed) {
                            $output = Receive-Job $job
                            $errors = $output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
                            
                            if ($errors.Count -gt 0) {
                                $errorCount++
                                Write-Host " ERROR" -ForegroundColor Red
                                $results += "[PowerShell] RUNTIME ERROR`n"
                                foreach ($err in $errors) {
                                    $results += "  $($err.Exception.Message)`n"
                                }
                            } else {
                                $successCount++
                                Write-Host " OK" -ForegroundColor Green
                                $results += "[PowerShell] OK`n"
                            }
                        } else {
                            $errorCount++
                            Write-Host " TIMEOUT" -ForegroundColor Yellow
                            $results += "[PowerShell] TIMEOUT (>10s)`n"
                        }
                        
                        Remove-Job $job -Force
                    }
                } catch {
                    $errorCount++
                    Write-Host " EXCEPTION" -ForegroundColor Red
                    $results += "[PowerShell] EXCEPTION: $($_.Exception.Message)`n"
                }
            }
        }
        
        # Test CMD script
        if ($TestAll -or $TestCMD) {
            $cmdScript = Join-Path $checkFolder.FullName "cmd.bat"
            if (Test-Path $cmdScript) {
                $totalScripts++
                Write-Host "    [CMD] Testing..." -NoNewline
                
                try {
                    # Run CMD script with timeout
                    $psi = New-Object System.Diagnostics.ProcessStartInfo
                    $psi.FileName = "cmd.exe"
                    $psi.Arguments = "/c `"$cmdScript`""
                    $psi.RedirectStandardOutput = $true
                    $psi.RedirectStandardError = $true
                    $psi.UseShellExecute = $false
                    $psi.CreateNoWindow = $true
                    
                    $process = New-Object System.Diagnostics.Process
                    $process.StartInfo = $psi
                    $process.Start() | Out-Null
                    
                    $completed = $process.WaitForExit(10000) # 10 second timeout
                    
                    if ($completed) {
                        $stderr = $process.StandardError.ReadToEnd()
                        
                        if ($stderr -and $stderr.Trim().Length -gt 0) {
                            $errorCount++
                            Write-Host " ERROR" -ForegroundColor Red
                            $results += "[CMD] ERROR`n"
                            $results += "  $stderr`n"
                        } else {
                            $successCount++
                            Write-Host " OK" -ForegroundColor Green
                            $results += "[CMD] OK`n"
                        }
                    } else {
                        $process.Kill()
                        $errorCount++
                        Write-Host " TIMEOUT" -ForegroundColor Yellow
                        $results += "[CMD] TIMEOUT (>10s)`n"
                    }
                } catch {
                    $errorCount++
                    Write-Host " EXCEPTION" -ForegroundColor Red
                    $results += "[CMD] EXCEPTION: $($_.Exception.Message)`n"
                }
            }
        }
    }
}

# Summary
$summary = @"

========================================
SUMMARY
========================================
Total Scripts Tested: $totalScripts
Successful: $successCount
Errors: $errorCount
Syntax Errors: $syntaxErrorCount
Success Rate: $([math]::Round(($successCount / $totalScripts) * 100, 2))%

Test Completed: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
========================================
"@

$results += $summary

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Scripts Tested: $totalScripts"
Write-Host "Successful: $successCount" -ForegroundColor Green
Write-Host "Errors: $errorCount" -ForegroundColor Red
Write-Host "Syntax Errors: $syntaxErrorCount" -ForegroundColor Red
Write-Host "Success Rate: $([math]::Round(($successCount / $totalScripts) * 100, 2))%" -ForegroundColor $(if ($successCount -eq $totalScripts) { "Green" } else { "Yellow" })
Write-Host ""

# Save results to file
$outputPath = Join-Path $SuiteRoot $OutputFile
$results | Out-File -FilePath $outputPath -Encoding UTF8
Write-Host "Results saved to: $outputPath" -ForegroundColor Green
Write-Host ""
