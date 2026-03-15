# Quick scan to check current Pattern A, B, C status
$suiteRoot = "C:\Users\acer\Downloads\AD_suiteXXX"

# Get all adsi.ps1 files (excluding backups)
$adsiFiles = Get-ChildItem -Path $suiteRoot -Recurse -Filter "adsi.ps1" | 
    Where-Object { $_.FullName -notmatch "\\backups" }

$patternABC = @()

foreach ($file in $adsiFiles) {
    try {
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$errors)
        
        if ($errors.Count -gt 0) {
            # Check for Pattern A, B, C signatures
            $hasPropertiesToLoadError = $errors | Where-Object { 
                $_.Message -match "Missing closing '\)' in expression" -or
                $_.Message -match "Unexpected token" 
            }
            
            if ($hasPropertiesToLoadError) {
                # Check if it's related to PropertiesToLoad
                $content = Get-Content $file.FullName -Raw
                if ($content -match "PropertiesToLoad\.Add") {
                    $patternABC += [PSCustomObject]@{
                        File = $file.FullName.Replace($suiteRoot + "\", "")
                        ErrorCount = $errors.Count
                        FirstError = "$($errors[0].Extent.StartLineNumber): $($errors[0].Message)"
                    }
                }
            }
        }
    } catch {
        Write-Warning "Error parsing $($file.FullName): $($_.Exception.Message)"
    }
}

Write-Host "=== Pattern A/B/C Files Still Needing PropertiesToLoad Fixes ===" -ForegroundColor Cyan
Write-Host "Found $($patternABC.Count) files with PropertiesToLoad syntax errors" -ForegroundColor Yellow
Write-Host ""

foreach ($item in $patternABC) {
    Write-Host "  $($item.File)" -ForegroundColor Red
    Write-Host "    Errors: $($item.ErrorCount) | First: $($item.FirstError)" -ForegroundColor Gray
}

if ($patternABC.Count -eq 0) {
    Write-Host "All Pattern A/B/C files appear to be fixed!" -ForegroundColor Green
}