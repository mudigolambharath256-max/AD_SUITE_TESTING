# Quick Script Validation
$categories = @('Access_Control','ACL_Permissions','Advanced_Security','Authentication','Azure_AD_Integration','Backup_Recovery','Certificate_Services','Computer_Management','Computers_Servers','Domain_Configuration','Group_Policy','Infrastructure','Kerberos_Security','LDAP_Security','Miscellaneous','Network_Security','Privileged_Access','Service_Accounts','Users_Accounts')

$results = @{
    PowerShell = @{ Total = 0; Errors = 0; Files = @() }
    ADSI = @{ Total = 0; Errors = 0; Files = @() }
    Combined = @{ Total = 0; Errors = 0; Files = @() }
    CSharp = @{ Total = 0; Errors = 0; Files = @() }
    Batch = @{ Total = 0; Errors = 0; Files = @() }
}

Write-Host "Validating scripts..." -ForegroundColor Cyan

foreach ($cat in $categories) {
    if (Test-Path $cat) {
        $folders = Get-ChildItem -Path $cat -Directory
        
        foreach ($folder in $folders) {
            # PowerShell
            $psFile = Join-Path $folder.FullName "powershell.ps1"
            if (Test-Path $psFile) {
                $results.PowerShell.Total++
                $errors = @()
                try {
                    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $psFile -Raw), [ref]$errors)
                    if ($errors.Count -gt 0) {
                        $results.PowerShell.Errors++
                        $results.PowerShell.Files += $psFile
                    }
                } catch {
                    $results.PowerShell.Errors++
                    $results.PowerShell.Files += $psFile
                }
            }
            
            # ADSI
            $adsiFile = Join-Path $folder.FullName "adsi.ps1"
            if (Test-Path $adsiFile) {
                $results.ADSI.Total++
                $errors = @()
                try {
                    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $adsiFile -Raw), [ref]$errors)
                    if ($errors.Count -gt 0) {
                        $results.ADSI.Errors++
                        $results.ADSI.Files += $adsiFile
                    }
                } catch {
                    $results.ADSI.Errors++
                    $results.ADSI.Files += $adsiFile
                }
            }
            
            # Combined
            $combinedFile = Join-Path $folder.FullName "combined_multiengine.ps1"
            if (Test-Path $combinedFile) {
                $results.Combined.Total++
                $errors = @()
                try {
                    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $combinedFile -Raw), [ref]$errors)
                    if ($errors.Count -gt 0) {
                        $results.Combined.Errors++
                        $results.Combined.Files += $combinedFile
                    }
                } catch {
                    $results.Combined.Errors++
                    $results.Combined.Files += $combinedFile
                }
            }
            
            # C#
            $csFile = Join-Path $folder.FullName "csharp.cs"
            if (Test-Path $csFile) {
                $results.CSharp.Total++
                $content = Get-Content $csFile -Raw
                $openBraces = ([regex]::Matches($content, '\{')).Count
                $closeBraces = ([regex]::Matches($content, '\}')).Count
                if ($openBraces -ne $closeBraces) {
                    $results.CSharp.Errors++
                    $results.CSharp.Files += $csFile
                }
            }
            
            # Batch
            $batFile = Join-Path $folder.FullName "cmd.bat"
            if (Test-Path $batFile) {
                $results.Batch.Total++
            }
        }
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Validation Results" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$totalScripts = 0
$totalErrors = 0

foreach ($type in $results.Keys) {
    $total = $results[$type].Total
    $errors = $results[$type].Errors
    $totalScripts += $total
    $totalErrors += $errors
    
    $color = if ($errors -gt 0) { "Red" } else { "Green" }
    Write-Host "$type : $total scripts, $errors errors" -ForegroundColor $color
    
    if ($errors -gt 0 -and $results[$type].Files.Count -gt 0) {
        foreach ($file in $results[$type].Files) {
            Write-Host "  - $file" -ForegroundColor Red
        }
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Total: $totalScripts scripts validated" -ForegroundColor White
if ($totalErrors -gt 0) {
    Write-Host "FAILED: $totalErrors scripts with errors" -ForegroundColor Red
} else {
    Write-Host "SUCCESS: All scripts validated!" -ForegroundColor Green
}
Write-Host "========================================`n" -ForegroundColor Cyan
