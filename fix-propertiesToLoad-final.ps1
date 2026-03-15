# Final fix for PropertiesToLoad syntax errors
$suiteRoot = "C:\Users\acer\Downloads\AD_suiteXXX"

# Files that need fixing based on our scan
$filesToFix = @(
    "Domain_Controllers\DC-012_DCs_with_Expiring_Certificates\DC-036_DCs_with_Expiring_Certificates\adsi.ps1",
    "Domain_Controllers\DC-013_DCs_Replication_Failures\DC-037_DCs_Replication_Failures\adsi.ps1",
    "Domain_Controllers\DC-014_DCs_Null_Session_Enabled\DC-038_DCs_Null_Session_Enabled\adsi.ps1",
    "Domain_Controllers\DC-015_DCs_with_Print_Spooler_Running\DC-039_DCs_with_Print_Spooler_Running\adsi.ps1"
)

Write-Host "=== Final PropertiesToLoad Fix ===" -ForegroundColor Cyan

foreach ($relativePath in $filesToFix) {
    $fullPath = Join-Path $suiteRoot $relativePath
    
    if (-not (Test-Path $fullPath)) {
        Write-Warning "File not found: $fullPath"
        continue
    }
    
    Write-Host "Processing: $relativePath" -ForegroundColor Yellow
    
    try {
        $content = Get-Content $fullPath -Raw
        $originalContent = $content
        
        # Fix the literal `r`n that was incorrectly added
        $content = $content -replace '}\)`r`n', '})'
        
        # Also fix any remaining issues with the PropertiesToLoad line
        $lines = $content -split "`r?`n"
        
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            
            # Look for PropertiesToLoad lines that need fixing
            if ($line -match 'PropertiesToLoad\.Add' -and $line -match '\}$' -and $line -notmatch '\}\)$') {
                # This line ends with } but should end with })
                $lines[$i] = $line + ')'
                Write-Host "  [FIXING] Line $($i+1): Added missing closing parenthesis" -ForegroundColor Green
            }
        }
        
        $content = $lines -join "`r`n"
        
        if ($content -ne $originalContent) {
            Set-Content -Path $fullPath -Value $content -Encoding UTF8
            Write-Host "  [SAVED] File updated" -ForegroundColor Green
            
            # Verify the fix
            $errors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile($fullPath, [ref]$null, [ref]$errors)
            
            if ($errors.Count -eq 0) {
                Write-Host "  [VERIFIED] File now parses without errors" -ForegroundColor Green
            } else {
                Write-Host "  [WARNING] File still has $($errors.Count) errors" -ForegroundColor Yellow
                $errors | ForEach-Object { Write-Host "    Line $($_.Extent.StartLineNumber): $($_.Message)" -ForegroundColor Gray }
            }
        } else {
            Write-Host "  [SKIP] No changes needed" -ForegroundColor Gray
        }
        
    } catch {
        Write-Error "Error processing $relativePath`: $($_.Exception.Message)"
    }
}

Write-Host ""
Write-Host "Running verification scan..." -ForegroundColor Yellow
& ".\check-pattern-abc-status.ps1"