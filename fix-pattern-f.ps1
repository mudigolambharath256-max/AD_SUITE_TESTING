# Fix Pattern F: TMGMT files missing closing brace at line 37
# Missing closing '}' in statement block or type definition

Write-Host "=== Fixing Pattern F: TMGMT Missing Closing Brace ===" -ForegroundColor Cyan

# Get all TMGMT files that have the Pattern F issue
$tmgmtFiles = Get-ChildItem -Path "Trust_Management" -Filter "adsi.ps1" -Recurse | Where-Object { $_.Directory.Name -match "TMGMT-" }

Write-Host "Found $($tmgmtFiles.Count) TMGMT files to check and fix" -ForegroundColor Yellow
Write-Host ""

$fixedCount = 0

foreach ($file in $tmgmtFiles) {
    Write-Host "Processing: $($file.Directory.Name)" -ForegroundColor Gray
    
    # Check if file has the Pattern F error
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$errors)
    
    $hasPatternF = $false
    if ($errors) {
        foreach ($error in $errors) {
            if ($error.Extent.StartLineNumber -eq 37 -and $error.Message -match "Missing closing.*}") {
                $hasPatternF = $true
                break
            }
        }
    }
    
    if ($hasPatternF) {
        Write-Host "  ✗ Has Pattern F error - fixing..." -ForegroundColor Yellow
        
        # Read the file content
        $content = Get-Content -Path $file.FullName -Raw
        
        # Fix the missing closing brace in the PropertiesToLoad ForEach-Object block
        # Look for the pattern and add the missing closing brace
        $fixedContent = $content -replace '(\@\([^)]+\)\s*\|\s*ForEach-Object\s*\{\s*\[void\]\$searcher\.PropertiesToLoad\.Add\(\$_\)\s*)\n(\s*#\s*Execute search)', '$1}' + "`n" + '$2'
        
        # Write the fixed content back
        $fixedContent | Out-File -FilePath $file.FullName -Encoding UTF8 -NoNewline
        
        # Verify the fix
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$errors)
        
        if ($errors.Count -eq 0) {
            Write-Host "  ✓ Fixed successfully (0 errors)" -ForegroundColor Green
            $fixedCount++
        } else {
            Write-Host "  ✗ Still has $($errors.Count) errors:" -ForegroundColor Red
            $errors | Select-Object -First 2 | ForEach-Object {
                Write-Host "    Line $($_.Extent.StartLineNumber): $($_.Message)" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "  ✓ No Pattern F error found" -ForegroundColor Green
    }
    
    Write-Host ""
}

Write-Host "Pattern F fix complete! Fixed $fixedCount files." -ForegroundColor Green