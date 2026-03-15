# Fix line break issues in PropertiesToLoad files
$suiteRoot = "C:\Users\acer\Downloads\AD_suiteXXX"

$filesToFix = @(
    "Domain_Controllers\DC-012_DCs_with_Expiring_Certificates\DC-036_DCs_with_Expiring_Certificates\adsi.ps1",
    "Domain_Controllers\DC-013_DCs_Replication_Failures\DC-037_DCs_Replication_Failures\adsi.ps1",
    "Domain_Controllers\DC-014_DCs_Null_Session_Enabled\DC-038_DCs_Null_Session_Enabled\adsi.ps1",
    "Domain_Controllers\DC-015_DCs_with_Print_Spooler_Running\DC-039_DCs_with_Print_Spooler_Running\adsi.ps1"
)

Write-Host "=== Fixing Line Break Issues ===" -ForegroundColor Cyan

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
        
        # Fix the missing line break after PropertiesToLoad
        $content = $content -replace '(\}\))\$', ('$1' + "`r`n" + '$')
        
        # More specific fixes for each pattern we've seen
        $content = $content -replace '(\}\))\$expirationThreshold', ('$1' + "`r`n" + '$expirationThreshold')
        $content = $content -replace '(\}\))\$results', ('$1' + "`r`n" + '$results')
        
        if ($content -ne $originalContent) {
            Set-Content -Path $fullPath -Value $content -Encoding UTF8
            Write-Host "  [FIXED] Added missing line break" -ForegroundColor Green
            
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