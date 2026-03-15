# Fix remaining line break issues
$suiteRoot = "C:\Users\acer\Downloads\AD_suiteXXX"

$filesToFix = @(
    "Domain_Controllers\DC-013_DCs_Replication_Failures\DC-037_DCs_Replication_Failures\adsi.ps1",
    "Domain_Controllers\DC-014_DCs_Null_Session_Enabled\DC-038_DCs_Null_Session_Enabled\adsi.ps1"
)

Write-Host "=== Fixing Remaining Line Break Issues ===" -ForegroundColor Cyan

foreach ($relativePath in $filesToFix) {
    $fullPath = Join-Path $suiteRoot $relativePath
    
    if (-not (Test-Path $fullPath)) {
        Write-Warning "File not found: $fullPath"
        continue
    }
    
    Write-Host "Processing: $relativePath" -ForegroundColor Yellow
    
    try {
        $lines = Get-Content $fullPath
        $modified = $false
        
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            
            # Look for the specific pattern: }) followed immediately by $results
            if ($line -match '(\}\))\s*\$results') {
                # Split this into two lines
                $lines[$i] = $line -replace '(\}\))\s*\$results', '$1'
                # Insert the $results line
                $lines = $lines[0..$i] + '    $results = $searcher.FindAll()' + $lines[($i+1)..($lines.Count-1)]
                $modified = $true
                Write-Host "  [FIXING] Line $($i+1): Split PropertiesToLoad and results assignment" -ForegroundColor Green
                break
            }
        }
        
        if ($modified) {
            Set-Content -Path $fullPath -Value $lines -Encoding UTF8
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