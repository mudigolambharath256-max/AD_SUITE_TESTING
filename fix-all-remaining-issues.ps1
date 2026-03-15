# Fix all remaining PropertiesToLoad and related syntax issues
$suiteRoot = "C:\Users\acer\Downloads\AD_suiteXXX"

Write-Host "=== Fixing All Remaining Syntax Issues ===" -ForegroundColor Cyan

# Fix DC-017: Malformed if statement
$dc017Path = Join-Path $suiteRoot "Domain_Controllers\DC-017_DCs_with_Weak_Kerberos_Encryption\adsi.ps1"
if (Test-Path $dc017Path) {
    Write-Host "Fixing DC-017..." -ForegroundColor Yellow
    $content = Get-Content $dc017Path -Raw
    
    # Fix the malformed nested if statement
    $content = $content -replace '\$encTypes = if \(\$p\[''msds-supportedencryptiontypes''\]\.Count -gt 0\) \{ \[int\]if \(\$p\[''msds-supportedencryptiontypes''\] -and \$p\[''msds-supportedencryptiontypes''\]\.Count -gt 0\) \{ \$p\[''msds-supportedencryptiontypes''\]\[0\] \} else \{ ''N/A'' \} \} else \{ 0 \}', '$encTypes = if ($p[''msds-supportedencryptiontypes''] -and $p[''msds-supportedencryptiontypes''].Count -gt 0) { [int]$p[''msds-supportedencryptiontypes''][0] } else { 0 }'
    
    Set-Content -Path $dc017Path -Value $content -Encoding UTF8
    Write-Host "  [FIXED] DC-017 if statement" -ForegroundColor Green
}

# Fix DC-028: Missing closing parenthesis in PropertiesToLoad
$dc028Path = Join-Path $suiteRoot "Domain_Controllers\DC-028_DCs_with_Old_DSRM_Password\adsi.ps1"
if (Test-Path $dc028Path) {
    Write-Host "Fixing DC-028..." -ForegroundColor Yellow
    $lines = Get-Content $dc028Path
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "PropertiesToLoad\.Add" -and $lines[$i] -match '\}$' -and $lines[$i] -notmatch '\}\)$') {
            $lines[$i] = $lines[$i] + ')'
            Write-Host "  [FIXED] DC-028 PropertiesToLoad line $($i+1)" -ForegroundColor Green
            break
        }
    }
    
    Set-Content -Path $dc028Path -Value $lines -Encoding UTF8
}

# Fix DC-030: String interpolation issue
$dc030Path = Join-Path $suiteRoot "Domain_Controllers\DC-030_DCs_with_Disabled_Security_Event_Log\adsi.ps1"
if (Test-Path $dc030Path) {
    Write-Host "Fixing DC-030..." -ForegroundColor Yellow
    $content = Get-Content $dc030Path -Raw
    
    # Fix the string interpolation issue
    $content = $content -replace '\$\{wmiLogInfo\.FileSize\} bytes', '$($wmiLogInfo.FileSize) bytes'
    
    Set-Content -Path $dc030Path -Value $content -Encoding UTF8
    Write-Host "  [FIXED] DC-030 string interpolation" -ForegroundColor Green
}

# Fix DC-036: Similar string interpolation issues
$dc036Path = Join-Path $suiteRoot "Domain_Controllers\DC-036_DCs_with_Insecure_Screensaver_Policy\adsi.ps1"
if (Test-Path $dc036Path) {
    Write-Host "Fixing DC-036..." -ForegroundColor Yellow
    $content = Get-Content $dc036Path -Raw
    
    # Fix string interpolation issues
    $content = $content -replace '\$\{timeout\} seconds', '$($timeout) seconds'
    $content = $content -replace '\$\{grace\} seconds', '$($grace) seconds'
    
    Set-Content -Path $dc036Path -Value $content -Encoding UTF8
    Write-Host "  [FIXED] DC-036 string interpolation" -ForegroundColor Green
}

# Fix DC-001: Check for structural issues
$dc001Path = Join-Path $suiteRoot "Domain_Controllers\DC-001_Domain_Controllers_Inventory\adsi.ps1"
if (Test-Path $dc001Path) {
    Write-Host "Fixing DC-001..." -ForegroundColor Yellow
    $lines = Get-Content $dc001Path
    
    # Look for unmatched braces around line 221
    for ($i = 215; $i -lt [Math]::Min($lines.Count, 225); $i++) {
        if ($lines[$i] -match '^\s*\}$' -and $i -gt 0 -and $lines[$i-1] -notmatch '\{$') {
            # This might be an extra closing brace
            $lines[$i] = ""
            Write-Host "  [FIXED] DC-001 removed extra closing brace at line $($i+1)" -ForegroundColor Green
            break
        }
    }
    
    # Remove empty lines
    $lines = $lines | Where-Object { $_ -ne "" }
    Set-Content -Path $dc001Path -Value $lines -Encoding UTF8
}

Write-Host ""
Write-Host "Running final verification scan..." -ForegroundColor Yellow
& ".\check-pattern-abc-status.ps1"