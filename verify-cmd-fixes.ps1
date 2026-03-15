# Verify CMD Engine Fixes - Task 3.5
# Validates that the 3 specific CMD syntax issues have been resolved

Write-Host "=== CMD Engine Fix Verification - Task 3.5 ===" -ForegroundColor Cyan
Write-Host "Verifying fixes for 3 specific CMD syntax issues..." -ForegroundColor Yellow

$verificationResults = @{
    SVC_Verified = 0
    SVC_Issues = @()
    DC_Verified = $false
    DC_Issues = @()
    TRST_Verified = $false
    TRST_Issues = @()
}

# Verify 1: SVC-001 to SVC-030 OID filter removal
Write-Host "`n1. Verifying SVC-001 to SVC-030 OID filter fixes..." -ForegroundColor Green

for ($i = 1; $i -le 30; $i++) {
    $svcId = "SVC-{0:D3}" -f $i
    $svcDirs = Get-ChildItem -Path "Service_Accounts" -Directory -Filter "${svcId}_*"
    
    if ($svcDirs.Count -eq 0) {
        $verificationResults.SVC_Issues += "Directory not found for $svcId"
        continue
    }
    
    $cmdFile = Join-Path $svcDirs[0].FullName "cmd.bat"
    if (-not (Test-Path $cmdFile)) {
        $verificationResults.SVC_Issues += "cmd.bat not found for $svcId"
        continue
    }
    
    $content = Get-Content $cmdFile -Raw
    
    # Check that OID filters have been removed
    if ($content -match 'userAccountControl:1\.2\.840\.113556\.1\.4\.803:=') {
        $verificationResults.SVC_Issues += "$svcId still contains OID filter"
    }
    # Check that dsquery uses %DCPATH%
    elseif ($content -notmatch 'dsquery \* %DCPATH%') {
        $verificationResults.SVC_Issues += "$svcId doesn't use %DCPATH%"
    }
    # Check that basic service account filter is present
    elseif ($content -notmatch 'servicePrincipalName=\*') {
        $verificationResults.SVC_Issues += "$svcId missing servicePrincipalName filter"
    }
    else {
        $verificationResults.SVC_Verified++
        Write-Host "  ✓ ${svcId}: OID filter removed, using simplified syntax" -ForegroundColor Green
    }
}

# Verify 2: DC-013 dsquery object type parameter fix
Write-Host "`n2. Verifying DC-013 dsquery object type parameter fix..." -ForegroundColor Green

$dc13Path = "Domain_Controllers\DC-013_DCs_Replication_Failures\cmd.bat"
if (Test-Path $dc13Path) {
    $content = Get-Content $dc13Path -Raw
    
    # Check that dsquery computer has been changed to dsquery *
    if ($content -match 'dsquery computer -filter') {
        $verificationResults.DC_Issues += "DC-013 still uses 'dsquery computer -filter'"
    }
    # Check that dsquery * is used instead
    elseif ($content -notmatch 'dsquery \* %DCPATH%') {
        $verificationResults.DC_Issues += "DC-013 doesn't use 'dsquery * %DCPATH%'"
    }
    # Check that OID filters have been removed
    elseif ($content -match 'userAccountControl:1\.2\.840\.113556\.1\.4\.803:=') {
        $verificationResults.DC_Issues += "DC-013 still contains OID filter"
    }
    else {
        $verificationResults.DC_Verified = $true
        Write-Host "  ✓ DC-013: Changed to 'dsquery *' and removed OID filter" -ForegroundColor Green
    }
} else {
    $verificationResults.DC_Issues += "DC-013 cmd.bat not found"
}

# Verify 3: TRST-031 startnode DN format fix
Write-Host "`n3. Verifying TRST-031 startnode DN format fix..." -ForegroundColor Green

$trst31Path = "Trust_Relationships\TRST-031_ExtraSIDs_Cross_Forest_Attack_Surface\cmd.bat"
if (Test-Path $trst31Path) {
    $content = Get-Content $trst31Path -Raw
    
    # Check that %USERDNSDOMAIN% has been replaced with %DCPATH%
    if ($content -match '%USERDNSDOMAIN%') {
        $verificationResults.TRST_Issues += "TRST-031 still uses %USERDNSDOMAIN%"
    }
    # Check that %DCPATH% is used in startnode
    elseif ($content -notmatch 'CN=System,%DCPATH%') {
        $verificationResults.TRST_Issues += "TRST-031 doesn't use %DCPATH% in startnode"
    }
    else {
        $verificationResults.TRST_Verified = $true
        Write-Host "  ✓ TRST-031: Changed to use %DCPATH% in startnode" -ForegroundColor Green
    }
} else {
    $verificationResults.TRST_Issues += "TRST-031 cmd.bat not found"
}

# Summary
Write-Host "`n=== Verification Summary ===" -ForegroundColor Cyan
Write-Host "SVC files verified: $($verificationResults.SVC_Verified)/30" -ForegroundColor $(if ($verificationResults.SVC_Verified -eq 30) { 'Green' } else { 'Yellow' })
Write-Host "DC-013 verified: $($verificationResults.DC_Verified)" -ForegroundColor $(if ($verificationResults.DC_Verified) { 'Green' } else { 'Red' })
Write-Host "TRST-031 verified: $($verificationResults.TRST_Verified)" -ForegroundColor $(if ($verificationResults.TRST_Verified) { 'Green' } else { 'Red' })

$totalIssues = $verificationResults.SVC_Issues.Count + $verificationResults.DC_Issues.Count + $verificationResults.TRST_Issues.Count

if ($totalIssues -gt 0) {
    Write-Host "`nIssues found:" -ForegroundColor Red
    $verificationResults.SVC_Issues | ForEach-Object { Write-Host "  SVC: $_" -ForegroundColor Red }
    $verificationResults.DC_Issues | ForEach-Object { Write-Host "  DC: $_" -ForegroundColor Red }
    $verificationResults.TRST_Issues | ForEach-Object { Write-Host "  TRST: $_" -ForegroundColor Red }
} else {
    Write-Host "`n✓ All CMD engine fixes verified successfully!" -ForegroundColor Green
}

Write-Host "`nCMD engine fix verification completed!" -ForegroundColor Cyan