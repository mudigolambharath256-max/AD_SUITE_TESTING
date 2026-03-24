# Fix all C# scripts by moving ExportToBloodHound outside Main()
$fixed = 0
$failed = 0

$files = @(
    "COMP-001_Computers_with_Unconstrained_Delegation",
    "COMP-002_Computers_with_Constrained_Delegation",
    "COMP-003_Computers_with_RBCD_Configured",
    "COMP-004_Computers_with_LAPS_Deployed",
    "COMP-005_Computers_Missing_LAPS",
    "COMP-006_Computers_Running_Unsupported_OS",
    "COMP-007_Stale_Computer_Accounts_90_Days",
    "COMP-008_Computers_with_adminCount1",
    "COMP-009_Computers_with_SIDHistory",
    "COMP-010_Computers_with_KeyCredentialLink",
    "COMP-011_Windows_Servers_Inventory",
    "COMP-012_Windows_Workstations_Inventory",
    "COMP-013_Computers_with_S4U_Delegation",
    "COMP-014_Computers_with_DES-Only_Kerberos",
    "COMP-015_Computers_Missing_Encryption_Types",
    "COMP-016_Computers_with_Reversible_Encryption",
    "COMP-017_Computers_Trusted_as_DCs_Not_Actual_DCs",
    "COMP-018_Computers_with_Pre-2000_Compatible_Access",
    "COMP-019_Computers_Created_in_Last_7_Days",
    "COMP-020_Disabled_Computer_Accounts",
    "COMP-021_Computers_with_userPassword_Attribute",
    "COMP-022_Computers_with_Description_Containing_Sensitive_Info",
    "COMP-023_Computers_in_Default_Computers_Container",
    "COMP-024_Computers_with_Service_Principal_Names",
    "COMP-025_Computers_with_AltSecurityIdentities",
    "COMP-026_Computer_Accounts_with_Old_Password_1_Year",
    "COMP-027_Computers_-_Windows_10_Versions",
    "COMP-028_Computers_-_Windows_11_Versions",
    "COMP-029_LinuxUnix_Computers",
    "COMP-030_Computers_with_Managed_Password_gMSA_Hosts"
)

Write-Host "Fixing C# scripts in Computers_Servers..." -ForegroundColor Cyan
Write-Host ""

foreach ($folder in $files) {
    $filePath = "Computers_Servers\$folder\csharp.cs"
    
    if (-not (Test-Path $filePath)) {
        Write-Host "SKIP: $folder - File not found" -ForegroundColor Yellow
        continue
    }
    
    Write-Host "Processing: $folder" -ForegroundColor Yellow
    
    try {
        $content = Get-Content $filePath -Raw
        
        # Find the ExportToBloodHound function and extract it
        $exportFunctionPattern = '(?s)(static void ExportToBloodHound.*?\n        \}\n)'
        
        if ($content -match $exportFunctionPattern) {
            $exportFunction = $matches[1]
            
            # Remove the function from inside Main
            $contentWithoutExport = $content -replace [regex]::Escape($exportFunction), ''
            
            # Find where to insert it (after class Program { and before static void Main)
            $newContent = $contentWithoutExport -replace '(class Program\s*\{)', "`$1`n  $exportFunction"
            
            # Fix indentation of the moved function (change from 8 spaces to 2 spaces)
            $exportFunctionFixed = $exportFunction -replace '(?m)^        ', '  '
            $newContent = $contentWithoutExport -replace '(class Program\s*\{)', "`$1`n$exportFunctionFixed"
            
            # Save the file
            Set-Content -Path $filePath -Value $newContent -Encoding UTF8 -NoNewline
            
            # Verify
            $verify = Get-Content $filePath -Raw
            $openBraces = ([regex]::Matches($verify, '\{')).Count
            $closeBraces = ([regex]::Matches($verify, '\}')).Count
            
            if ($openBraces -eq $closeBraces) {
                Write-Host "  SUCCESS: Fixed ($openBraces/$closeBraces braces)" -ForegroundColor Green
                $fixed++
            } else {
                Write-Host "  FAILED: Still mismatched ($openBraces/$closeBraces braces)" -ForegroundColor Red
                $failed++
            }
        } else {
            Write-Host "  FAILED: Could not find ExportToBloodHound function" -ForegroundColor Red
            $failed++
        }
        
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $failed++
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Fixed: $fixed / 30" -ForegroundColor $(if ($fixed -eq 30) { "Green" } else { "Yellow" })
Write-Host "Failed: $failed / 30" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
Write-Host "========================================" -ForegroundColor Cyan
