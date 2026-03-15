# Check BloodHound/Cysto JSON Export Compatibility
# This script verifies if all AD Suite scripts export data in BloodHound-compatible JSON format

param(
    [string]$SuiteRoot = "C:\users\vagrant\Desktop\AD_SUITE_TESTING",
    [string]$OutputFile = "bloodhound-export-check.txt"
)

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$results = @()
$totalScripts = 0
$hasBloodHoundExport = 0
$missingBloodHoundExport = 0
$hasJSONOutput = 0
$missingJSONOutput = 0

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "BloodHound/Cysto Export Compatibility Check" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Started: $timestamp" -ForegroundColor Gray
Write-Host "Suite Root: $SuiteRoot" -ForegroundColor Gray
Write-Host ""

# Output header
$header = @"
========================================
BLOODHOUND/CYSTO EXPORT COMPATIBILITY CHECK
========================================
Test Date: $timestamp
Suite Root: $SuiteRoot

Checking for:
1. BloodHound export functionality (SharpHound integration)
2. JSON output format compatibility
3. Cysto-compatible data structures

"@

$results += $header

# Get all category folders
$categories = Get-ChildItem -Path $SuiteRoot -Directory | Where-Object { 
    $_.Name -notmatch '^(ad-suite-web|backups|\.git|\.vscode|node_modules|AD_suiteXXX)' 
}

Write-Host "Found $($categories.Count) categories to check" -ForegroundColor Green
Write-Host ""

foreach ($category in $categories) {
    Write-Host "Checking Category: $($category.Name)" -ForegroundColor Yellow
    $results += "`n========================================`n"
    $results += "CATEGORY: $($category.Name)`n"
    $results += "========================================`n"
    
    # Get all check folders in this category
    $checkFolders = Get-ChildItem -Path $category.FullName -Directory
    
    foreach ($checkFolder in $checkFolders) {
        $checkId = $checkFolder.Name
        Write-Host "  Checking: $checkId" -ForegroundColor Cyan
        
        $results += "`n--- CHECK: $checkId ---`n"
        
        # Check all script types
        $scriptFiles = @(
            @{Name="ADSI"; Path=(Join-Path $checkFolder.FullName "adsi.ps1")},
            @{Name="PowerShell"; Path=(Join-Path $checkFolder.FullName "powershell.ps1")},
            @{Name="Combined"; Path=(Join-Path $checkFolder.FullName "combined_multiengine.ps1")}
        )
        
        foreach ($scriptInfo in $scriptFiles) {
            if (Test-Path $scriptInfo.Path) {
                $totalScripts++
                $scriptContent = Get-Content $scriptInfo.Path -Raw
                
                # Check for BloodHound export functionality
                $hasBloodHound = $false
                $hasJSON = $false
                $hasCysto = $false
                
                # Check for BloodHound-related code
                if ($scriptContent -match 'SharpHound|BloodHound|bloodhound|Export-BloodHound|Invoke-BloodHound') {
                    $hasBloodHound = $true
                    $hasBloodHoundExport++
                }
                
                # Check for JSON export
                if ($scriptContent -match 'ConvertTo-Json|Export-Json|\.json|ToJson\(\)|\| Out-File.*\.json') {
                    $hasJSON = $true
                    $hasJSONOutput++
                }
                
                # Check for Cysto compatibility markers
                if ($scriptContent -match 'Cysto|cysto|bloodhound_data|neo4j') {
                    $hasCysto = $true
                }
                
                # Report findings
                $status = ""
                if ($hasBloodHound -and $hasJSON) {
                    $status = "FULL SUPPORT"
                    Write-Host "    [$($scriptInfo.Name)] " -NoNewline
                    Write-Host "✓ BloodHound + JSON" -ForegroundColor Green
                } elseif ($hasBloodHound) {
                    $status = "BLOODHOUND ONLY"
                    Write-Host "    [$($scriptInfo.Name)] " -NoNewline
                    Write-Host "⚠ BloodHound (no JSON)" -ForegroundColor Yellow
                } elseif ($hasJSON) {
                    $status = "JSON ONLY"
                    Write-Host "    [$($scriptInfo.Name)] " -NoNewline
                    Write-Host "⚠ JSON (no BloodHound)" -ForegroundColor Yellow
                } else {
                    $status = "NO EXPORT"
                    $missingBloodHoundExport++
                    $missingJSONOutput++
                    Write-Host "    [$($scriptInfo.Name)] " -NoNewline
                    Write-Host "✗ No export found" -ForegroundColor Red
                }
                
                $results += "[$($scriptInfo.Name)] $status`n"
                
                # Check for specific BloodHound data structures
                if ($hasBloodHound -or $hasJSON) {
                    $dataStructures = @()
                    
                    if ($scriptContent -match 'ObjectIdentifier|objectid') { $dataStructures += "ObjectIdentifier" }
                    if ($scriptContent -match 'Properties') { $dataStructures += "Properties" }
                    if ($scriptContent -match 'Aces|ACEs') { $dataStructures += "ACEs" }
                    if ($scriptContent -match 'Members') { $dataStructures += "Members" }
                    if ($scriptContent -match 'Sessions') { $dataStructures += "Sessions" }
                    if ($scriptContent -match 'SPNTargets') { $dataStructures += "SPNTargets" }
                    if ($scriptContent -match 'AllowedToDelegate') { $dataStructures += "AllowedToDelegate" }
                    
                    if ($dataStructures.Count -gt 0) {
                        $results += "  Data Structures: $($dataStructures -join ', ')`n"
                    }
                }
                
                # Check for JSON structure validation
                if ($hasJSON) {
                    $hasValidation = $false
                    if ($scriptContent -match 'Test-Json|ConvertFrom-Json.*ConvertTo-Json|json.*valid') {
                        $hasValidation = $true
                        $results += "  ✓ JSON validation present`n"
                    } else {
                        $results += "  ⚠ No JSON validation found`n"
                    }
                }
            }
        }
    }
}

# Calculate statistics
$bloodhoundPercentage = if ($totalScripts -gt 0) { [math]::Round(($hasBloodHoundExport / $totalScripts) * 100, 2) } else { 0 }
$jsonPercentage = if ($totalScripts -gt 0) { [math]::Round(($hasJSONOutput / $totalScripts) * 100, 2) } else { 0 }

# Summary
$summary = @"

========================================
SUMMARY
========================================
Total Scripts Checked: $totalScripts

BloodHound Export:
  - Scripts with BloodHound: $hasBloodHoundExport ($bloodhoundPercentage%)
  - Scripts without BloodHound: $missingBloodHoundExport

JSON Export:
  - Scripts with JSON: $hasJSONOutput ($jsonPercentage%)
  - Scripts without JSON: $missingJSONOutput

Compatibility Status:
"@

if ($bloodhoundPercentage -eq 100 -and $jsonPercentage -eq 100) {
    $summary += "  ✓ FULLY COMPATIBLE - All scripts support BloodHound and JSON export`n"
} elseif ($bloodhoundPercentage -ge 50 -or $jsonPercentage -ge 50) {
    $summary += "  ⚠ PARTIALLY COMPATIBLE - Some scripts missing export functionality`n"
} else {
    $summary += "  ✗ LIMITED COMPATIBILITY - Most scripts need export functionality added`n"
}

$summary += @"

Recommendations:
"@

if ($missingBloodHoundExport -gt 0) {
    $summary += "  1. Add BloodHound export to $missingBloodHoundExport scripts`n"
}
if ($missingJSONOutput -gt 0) {
    $summary += "  2. Add JSON output to $missingJSONOutput scripts`n"
}
if ($bloodhoundPercentage -lt 100 -or $jsonPercentage -lt 100) {
    $summary += "  3. Standardize export format across all scripts`n"
    $summary += "  4. Add JSON validation to ensure data integrity`n"
    $summary += "  5. Test BloodHound import compatibility`n"
}

$summary += @"

Test Completed: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
========================================
"@

$results += $summary

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Scripts Checked: $totalScripts"
Write-Host ""
Write-Host "BloodHound Export:" -ForegroundColor Yellow
Write-Host "  With BloodHound: $hasBloodHoundExport ($bloodhoundPercentage%)" -ForegroundColor $(if ($bloodhoundPercentage -eq 100) { "Green" } else { "Yellow" })
Write-Host "  Without BloodHound: $missingBloodHoundExport" -ForegroundColor $(if ($missingBloodHoundExport -eq 0) { "Green" } else { "Red" })
Write-Host ""
Write-Host "JSON Export:" -ForegroundColor Yellow
Write-Host "  With JSON: $hasJSONOutput ($jsonPercentage%)" -ForegroundColor $(if ($jsonPercentage -eq 100) { "Green" } else { "Yellow" })
Write-Host "  Without JSON: $missingJSONOutput" -ForegroundColor $(if ($missingJSONOutput -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($bloodhoundPercentage -eq 100 -and $jsonPercentage -eq 100) {
    Write-Host "✓ FULLY COMPATIBLE" -ForegroundColor Green
} elseif ($bloodhoundPercentage -ge 50 -or $jsonPercentage -ge 50) {
    Write-Host "⚠ PARTIALLY COMPATIBLE" -ForegroundColor Yellow
} else {
    Write-Host "✗ LIMITED COMPATIBILITY" -ForegroundColor Red
}
Write-Host ""

# Save results to file
$outputPath = Join-Path $SuiteRoot $OutputFile
$results | Out-File -FilePath $outputPath -Encoding UTF8
Write-Host "Results saved to: $outputPath" -ForegroundColor Green
Write-Host ""

# Return statistics for programmatic use
return @{
    TotalScripts = $totalScripts
    HasBloodHound = $hasBloodHoundExport
    HasJSON = $hasJSONOutput
    MissingBloodHound = $missingBloodHoundExport
    MissingJSON = $missingJSONOutput
    BloodHoundPercentage = $bloodhoundPercentage
    JSONPercentage = $jsonPercentage
}
