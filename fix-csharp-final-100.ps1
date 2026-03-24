# Fix all C# files to 100%
Write-Host "Fixing all 30 C# files..." -ForegroundColor Cyan
Write-Host ""

$fixed = 0
$failed = 0

for ($i = 1; $i -le 30; $i++) {
    $pattern = "COMP-{0:D3}_*" -f $i
    $dir = Get-ChildItem -Path "Computers_Servers" -Directory -Filter $pattern | Select-Object -First 1
    
    if (-not $dir) { continue }
    
    $file = Join-Path $dir.FullName "csharp.cs"
    if (-not (Test-Path $file)) { continue }
    
    Write-Host "Processing: $($dir.Name)" -ForegroundColor Yellow
    
    try {
        $content = Get-Content $file -Raw
        
        # Fix the literal `n that should be an actual newline
        $newline = [Environment]::NewLine
        $content = $content -replace '(\(.*?\))``n  \{', "`$1$newline  {"
        
        # Save
        Set-Content -Path $file -Value $content -Encoding UTF8 -NoNewline
        
        # Verify
        $verify = Get-Content $file -Raw
        $openBraces = ([regex]::Matches($verify, '\{')).Count
        $closeBraces = ([regex]::Matches($verify, '\}')).Count
        
        if ($openBraces -eq $closeBraces) {
            Write-Host "  SUCCESS: $openBraces/$closeBraces braces match" -ForegroundColor Green
            $fixed++
        } else {
            Write-Host "  FAILED: $openBraces open, $closeBraces close" -ForegroundColor Red
            $failed++
        }
        
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $failed++
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
if ($fixed -eq 30) {
    Write-Host "SUCCESS: All 30 files fixed! 100% complete!" -ForegroundColor Green
} else {
    Write-Host "Fixed: $fixed / 30" -ForegroundColor Yellow
    Write-Host "Failed: $failed / 30" -ForegroundColor Red
}
Write-Host "========================================" -ForegroundColor Cyan
