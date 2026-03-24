# Final comprehensive fix for all C# files
Write-Host "Applying final fix to all C# files..." -ForegroundColor Cyan

for ($i = 1; $i -le 30; $i++) {
    $pattern = "COMP-{0:D3}_*" -f $i
    $dir = Get-ChildItem -Path "Computers_Servers" -Directory -Filter $pattern | Select-Object -First 1
    
    if (-not $dir) { continue }
    
    $file = Join-Path $dir.FullName "csharp.cs"
    if (-not (Test-Path $file)) { continue }
    
    Write-Host "Fixing: $($dir.Name)" -ForegroundColor Yellow
    
    $content = Get-Content $file -Raw
    
    # Fix: Ensure the opening brace after ExportToBloodHound is on the same line or properly indented
    $content = $content -replace '(?m)^    static void ExportToBloodHound\((.*?)\)\r?\n  \{', '  static void ExportToBloodHound($1)`n  {'
    
    Set-Content -Path $file -Value $content -Encoding UTF8 -NoNewline
}

Write-Host ""
Write-Host "Verifying fixes..." -ForegroundColor Cyan

$fixed = 0
$failed = 0

for ($i = 1; $i -le 30; $i++) {
    $pattern = "COMP-{0:D3}_*" -f $i
    $dir = Get-ChildItem -Path "Computers_Servers" -Directory -Filter $pattern | Select-Object -First 1
    
    if ($dir) {
        $file = Join-Path $dir.FullName "csharp.cs"
        if (Test-Path $file) {
            $content = Get-Content $file -Raw
            $openBraces = ([regex]::Matches($content, '\{')).Count
            $closeBraces = ([regex]::Matches($content, '\}')).Count
            
            if ($openBraces -eq $closeBraces) {
                Write-Host "  OK: $($dir.Name)" -ForegroundColor Green
                $fixed++
            } else {
                Write-Host "  FAIL: $($dir.Name) - $openBraces open, $closeBraces close" -ForegroundColor Red
                $failed++
            }
        }
    }
}

Write-Host ""
if ($fixed -eq 30) {
    Write-Host "SUCCESS: All 30 files fixed!" -ForegroundColor Green
} else {
    Write-Host "PARTIAL: $fixed fixed, $failed still have issues" -ForegroundColor Yellow
}
