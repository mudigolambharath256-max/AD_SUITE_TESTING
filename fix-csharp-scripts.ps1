# Fix C# Scripts - Move ExportToBloodHound function outside Main()
$ErrorActionPreference = "Stop"

$fixed = 0
$failed = 0
$skipped = 0

Write-Host "Starting C# script fixes..." -ForegroundColor Cyan
Write-Host ""

$csFiles = Get-ChildItem -Path "Computers_Servers" -Recurse -Filter "csharp.cs"

foreach ($file in $csFiles) {
    Write-Host "Processing: $($file.Directory.Name)" -ForegroundColor Yellow
    
    try {
        $content = Get-Content $file.FullName -Raw
        
        # Check if file has the issue
        $openBraces = ([regex]::Matches($content, '\{')).Count
        $closeBraces = ([regex]::Matches($content, '\}')).Count
        
        if ($openBraces -eq $closeBraces) {
            Write-Host "  SKIP: Already correct" -ForegroundColor Green
            $skipped++
            continue
        }
        
        # Extract the ExportToBloodHound function
        $pattern = '(?s)(static void Main\(\)\s*\{.*?string filter = .*?;)\s*(static void ExportToBloodHound.*?\n\s+\})\s*(string\[\] props = .*)'
        
        if ($content -match $pattern) {
            $beforeFunction = $matches[1]
            $exportFunction = $matches[2]
            $afterFunction = $matches[3]
            
            # Reconstruct the file with proper structure
            $newContent = $content -replace $pattern, @"
$exportFunction

  static void Main()
  {
    string filter = $($matches[1] -replace '.*string filter = (.*?);.*', '$1');

    $afterFunction
"@
            
            # Save the fixed content
            Set-Content -Path $file.FullName -Value $newContent -Encoding UTF8
            
            # Verify the fix
            $newOpenBraces = ([regex]::Matches($newContent, '\{')).Count
            $newCloseBraces = ([regex]::Matches($newContent, '\}')).Count
            
            if ($newOpenBraces -eq $newCloseBraces) {
                Write-Host "  FIXED: Braces now match ($newOpenBraces/$newCloseBraces)" -ForegroundColor Green
                $fixed++
            } else {
                Write-Host "  PARTIAL: Still has issues ($newOpenBraces/$newCloseBraces)" -ForegroundColor Yellow
                $failed++
            }
        } else {
            Write-Host "  ERROR: Pattern not found, manual fix needed" -ForegroundColor Red
            $failed++
        }
        
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $failed++
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Fix Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Fixed: $fixed" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor Red
Write-Host "Skipped: $skipped" -ForegroundColor Yellow
Write-Host "Total: $($csFiles.Count)" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
