# Final fix for all C# scripts
$folders = 1..30 | ForEach-Object { "COMP-{0:D3}" -f $_ }

$fixed = 0
$failed = 0

Write-Host "Fixing C# scripts..." -ForegroundColor Cyan

foreach ($num in 1..30) {
    $folder = "COMP-{0:D3}_*" -f $num
    $dir = Get-ChildItem -Path "Computers_Servers" -Directory -Filter $folder | Select-Object -First 1
    
    if (-not $dir) {
        Write-Host "SKIP: COMP-{0:D3} - Not found" -f $num -ForegroundColor Yellow
        continue
    }
    
    $filePath = Join-Path $dir.FullName "csharp.cs"
    
    if (-not (Test-Path $filePath)) {
        Write-Host "SKIP: $($dir.Name) - File not found" -ForegroundColor Yellow
        continue
    }
    
    Write-Host "Processing: $($dir.Name)" -ForegroundColor Yellow
    
    try {
        $content = Get-Content $filePath -Raw
        
        # Fix the extra blank lines and indentation in Main
        $content = $content -replace '(?m)^    string filter = (.*?);[\r\n]+[\r\n]+\s+string\[\] props', "    string filter = `$1;`n    string[] props"
        
        Set-Content -Path $filePath -Value $content -Encoding UTF8 -NoNewline
        
        # Verify
        $verify = Get-Content $filePath -Raw
        $openBraces = ([regex]::Matches($verify, '\{')).Count
        $closeBraces = ([regex]::Matches($verify, '\}')).Count
        
        if ($openBraces -eq $closeBraces) {
            Write-Host "  SUCCESS: $openBraces/$closeBraces braces" -ForegroundColor Green
            $fixed++
        } else {
            Write-Host "  STILL BROKEN: $openBraces/$closeBraces braces" -ForegroundColor Red
            $failed++
        }
        
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $failed++
    }
}

Write-Host ""
Write-Host "Fixed: $fixed / 30" -ForegroundColor $(if ($fixed -eq 30) { "Green" } else { "Yellow" })
Write-Host "Failed: $failed / 30" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
