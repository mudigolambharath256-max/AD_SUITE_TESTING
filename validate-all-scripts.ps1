# Script Validation Tool
param(
    [string]$RootPath = ".",
    [switch]$Verbose
)

$ErrorActionPreference = "Continue"
$TotalErrors = 0
$TotalWarnings = 0
$TotalScripts = 0
$Results = @()

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Test-PowerShellScript {
    param([string]$FilePath)
    
    $script:TotalScripts++
    $errors = @()
    
    try {
        $content = Get-Content $FilePath -Raw -ErrorAction Stop
        $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$errors)
        
        if ($errors.Count -gt 0) {
            $script:TotalErrors++
            Write-ColorOutput "FAIL: $FilePath" "Red"
            foreach ($err in $errors) {
                Write-ColorOutput "  Line $($err.Token.StartLine): $($err.Message)" "Red"
            }
            $script:Results += [PSCustomObject]@{
                Type = "PowerShell"
                File = $FilePath
                Status = "FAILED"
                Errors = $errors.Count
            }
            return $false
        } else {
            if ($Verbose) { Write-ColorOutput "OK: $FilePath" "Green" }
            $script:Results += [PSCustomObject]@{
                Type = "PowerShell"
                File = $FilePath
                Status = "OK"
                Errors = 0
            }
            return $true
        }
    } catch {
        $script:TotalErrors++
        Write-ColorOutput "EXCEPTION: $FilePath - $($_.Exception.Message)" "Red"
        $script:Results += [PSCustomObject]@{
            Type = "PowerShell"
            File = $FilePath
            Status = "EXCEPTION"
            Errors = 1
        }
        return $false
    }
}

function Test-CSharpScript {
    param([string]$FilePath)
    
    $script:TotalScripts++
    $content = Get-Content $FilePath -Raw
    $issues = @()
    
    $openBraces = ([regex]::Matches($content, '\{')).Count
    $closeBraces = ([regex]::Matches($content, '\}')).Count
    
    if ($openBraces -ne $closeBraces) {
        $issues += "Mismatched braces: $openBraces open, $closeBraces close"
    }
    
    if ($content -notmatch 'using System;') {
        $issues += "Missing using System directive"
    }
    
    if ($content -notmatch 'class\s+\w+') {
        $issues += "No class definition found"
    }
    
    if ($content -notmatch 'static\s+void\s+Main') {
        $issues += "No Main method found"
    }
    
    $stringMatches = [regex]::Matches($content, '"')
    if ($stringMatches.Count % 2 -ne 0) {
        $issues += "Unclosed string literal detected"
    }
    
    if ($issues.Count -gt 0) {
        $script:TotalErrors++
        Write-ColorOutput "FAIL: $FilePath" "Red"
        foreach ($issue in $issues) {
            Write-ColorOutput "  $issue" "Red"
        }
        $script:Results += [PSCustomObject]@{
            Type = "CSharp"
            File = $FilePath
            Status = "FAILED"
            Errors = $issues.Count
        }
        return $false
    } else {
        if ($Verbose) { Write-ColorOutput "OK: $FilePath" "Green" }
        $script:Results += [PSCustomObject]@{
            Type = "CSharp"
            File = $FilePath
            Status = "OK"
            Errors = 0
        }
        return $true
    }
}

function Test-BatchScript {
    param([string]$FilePath)
    
    $script:TotalScripts++
    $content = Get-Content $FilePath
    $issues = @()
    $lineNum = 0
    
    foreach ($line in $content) {
        $lineNum++
        $trimmed = $line.Trim()
        
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith("REM") -or $trimmed.StartsWith("::")) {
            continue
        }
        
        $openParens = ([regex]::Matches($trimmed, '\(')).Count
        $closeParens = ([regex]::Matches($trimmed, '\)')).Count
        if ($openParens -ne $closeParens) {
            $issues += "Line $lineNum : Mismatched parentheses"
        }
    }
    
    if ($issues.Count -gt 0) {
        $script:TotalWarnings++
        Write-ColorOutput "WARN: $FilePath" "Yellow"
        foreach ($issue in $issues) {
            Write-ColorOutput "  $issue" "Yellow"
        }
        $script:Results += [PSCustomObject]@{
            Type = "Batch"
            File = $FilePath
            Status = "WARNING"
            Errors = $issues.Count
        }
        return $false
    } else {
        if ($Verbose) { Write-ColorOutput "OK: $FilePath" "Green" }
        $script:Results += [PSCustomObject]@{
            Type = "Batch"
            File = $FilePath
            Status = "OK"
            Errors = 0
        }
        return $true
    }
}

Write-ColorOutput "========================================" "Cyan"
Write-ColorOutput "AD Suite Script Validation Tool" "Cyan"
Write-ColorOutput "========================================" "Cyan"
Write-Host ""

$startTime = Get-Date

Write-ColorOutput "Scanning for scripts in: $RootPath" "Cyan"

$categories = Get-ChildItem -Path $RootPath -Directory | Where-Object { 
    $_.Name -match '^(Access_Control|ACL_Permissions|Advanced_Security|Authentication|Azure_AD|Backup_Recovery|Certificate_Services|Computer_Management|Computers_Servers|Domain_Configuration|Group_Policy|Infrastructure|Kerberos_Security|LDAP_Security|Miscellaneous|Network_Security|Privileged_Access|Service_Accounts|Users_Accounts)'
}

Write-ColorOutput "Found $($categories.Count) categories to validate" "Cyan"
Write-Host ""

foreach ($category in $categories) {
    Write-ColorOutput "--- Validating: $($category.Name) ---" "Magenta"
    
    $checkFolders = Get-ChildItem -Path $category.FullName -Directory -ErrorAction SilentlyContinue
    
    foreach ($checkFolder in $checkFolders) {
        $psFiles = Get-ChildItem -Path $checkFolder.FullName -Filter "powershell.ps1" -ErrorAction SilentlyContinue
        foreach ($file in $psFiles) {
            Test-PowerShellScript -FilePath $file.FullName | Out-Null
        }
        
        $adsiFiles = Get-ChildItem -Path $checkFolder.FullName -Filter "adsi.ps1" -ErrorAction SilentlyContinue
        foreach ($file in $adsiFiles) {
            Test-PowerShellScript -FilePath $file.FullName | Out-Null
        }
        
        $combinedFiles = Get-ChildItem -Path $checkFolder.FullName -Filter "combined_multiengine.ps1" -ErrorAction SilentlyContinue
        foreach ($file in $combinedFiles) {
            Test-PowerShellScript -FilePath $file.FullName | Out-Null
        }
        
        $csFiles = Get-ChildItem -Path $checkFolder.FullName -Filter "csharp.cs" -ErrorAction SilentlyContinue
        foreach ($file in $csFiles) {
            Test-CSharpScript -FilePath $file.FullName | Out-Null
        }
        
        $batFiles = Get-ChildItem -Path $checkFolder.FullName -Filter "cmd.bat" -ErrorAction SilentlyContinue
        foreach ($file in $batFiles) {
            Test-BatchScript -FilePath $file.FullName | Out-Null
        }
    }
}

$endTime = Get-Date
$duration = $endTime - $startTime

Write-Host ""
Write-ColorOutput "========================================" "Cyan"
Write-ColorOutput "Validation Summary" "Cyan"
Write-ColorOutput "========================================" "Cyan"
Write-Host ""

Write-Host "Total Scripts Validated: $TotalScripts"
if ($TotalErrors -gt 0) {
    Write-ColorOutput "Errors Found: $TotalErrors" "Red"
} else {
    Write-ColorOutput "Errors Found: $TotalErrors" "Green"
}

if ($TotalWarnings -gt 0) {
    Write-ColorOutput "Warnings Found: $TotalWarnings" "Yellow"
} else {
    Write-ColorOutput "Warnings Found: $TotalWarnings" "Green"
}

Write-Host "Duration: $($duration.TotalSeconds) seconds"
Write-Host ""

$okCount = ($Results | Where-Object { $_.Status -eq "OK" }).Count
$failedCount = ($Results | Where-Object { $_.Status -eq "FAILED" }).Count
$warningCount = ($Results | Where-Object { $_.Status -eq "WARNING" }).Count
$exceptionCount = ($Results | Where-Object { $_.Status -eq "EXCEPTION" }).Count

Write-ColorOutput "Status Breakdown:" "Cyan"
Write-ColorOutput "  OK: $okCount" "Green"
Write-ColorOutput "  Failed: $failedCount" "Red"
Write-ColorOutput "  Warnings: $warningCount" "Yellow"
Write-ColorOutput "  Exceptions: $exceptionCount" "Red"

$reportFile = "validation-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
$Results | Export-Csv -Path $reportFile -NoTypeInformation
Write-Host ""
Write-ColorOutput "Detailed report saved to: $reportFile" "Cyan"

Write-Host ""
if ($TotalErrors -gt 0) {
    Write-ColorOutput "Validation FAILED - $TotalErrors errors found" "Red"
    exit 1
} elseif ($TotalWarnings -gt 0) {
    Write-ColorOutput "Validation completed with $TotalWarnings warnings" "Yellow"
    exit 0
} else {
    Write-ColorOutput "All scripts validated successfully!" "Green"
    exit 0
}
