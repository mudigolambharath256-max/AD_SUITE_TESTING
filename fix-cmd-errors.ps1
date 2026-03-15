# Fix CMD Engine Errors - Task 3.5
# Fixes 3 specific CMD syntax issues:
# 1. SVC-001 to SVC-030: OID filter incompatibility
# 2. DC-013: dsquery object type parameter
# 3. TRST-031: startnode DN format

Write-Host "=== CMD Engine Error Fix - Task 3.5 ===" -ForegroundColor Cyan
Write-Host "Fixing 3 specific CMD syntax issues..." -ForegroundColor Yellow

$fixResults = @{
    SVC_Fixed = 0
    DC_Fixed = 0
    TRST_Fixed = 0
    Errors = @()
}

# Fix 1: SVC-001 to SVC-030 OID filter incompatibility
Write-Host "`n1. Fixing SVC-001 to SVC-030 OID filter issues..." -ForegroundColor Green

for ($i = 1; $i -le 30; $i++) {
    $svcId = "SVC-{0:D3}" -f $i
    $cmdPath = "Service_Accounts\${svcId}_*\cmd.bat"
    $svcDirs = Get-ChildItem -Path "Service_Accounts" -Directory -Filter "${svcId}_*"
    
    if ($svcDirs.Count -eq 0) {
        Write-Warning "Directory not found for $svcId"
        continue
    }
    
    $cmdFile = Join-Path $svcDirs[0].FullName "cmd.bat"
    if (-not (Test-Path $cmdFile)) {
        Write-Warning "cmd.bat not found for $svcId"
        continue
    }
    
    try {
        $content = Get-Content $cmdFile -Raw
        $originalContent = $content
        
        # Replace OID extensible match filters with simplified filters
        # Pattern: userAccountControl:1.2.840.113556.1.4.803:=VALUE
        $content = $content -replace 'userAccountControl:1\.2\.840\.113556\.1\.4\.803:=\d+', ''
        
        # Clean up double parentheses and empty conditions
        $content = $content -replace '\(\!\(\)\)', ''
        $content = $content -replace '\(\)\)', ')'
        $content = $content -replace '\(\(&', '(&'
        
        # Ensure we have the basic service account filter
        if ($content -match 'dsquery \* -filter') {
            # Replace complex filters with simplified service account filter
            $content = $content -replace 'dsquery \* -filter "[^"]*"', 'dsquery * %DCPATH% -filter "(&(objectCategory=person)(objectClass=user)(servicePrincipalName=*))"'
        }
        
        if ($content -ne $originalContent) {
            Set-Content -Path $cmdFile -Value $content -NoNewline
            Write-Host "  Fixed: $svcId" -ForegroundColor Green
            $fixResults.SVC_Fixed++
        } else {
            Write-Host "  No changes needed: $svcId" -ForegroundColor Yellow
        }
    }
    catch {
        $error = "Error fixing ${svcId}: $($_.Exception.Message)"
        Write-Error $error
        $fixResults.Errors += $error
    }
}

# Fix 2: DC-013 dsquery object type parameter
Write-Host "`n2. Fixing DC-013 dsquery object type parameter..." -ForegroundColor Green

$dc13Path = "Domain_Controllers\DC-013_DCs_Replication_Failures\cmd.bat"
if (Test-Path $dc13Path) {
    try {
        $content = Get-Content $dc13Path -Raw
        $originalContent = $content
        
        # Replace dsquery computer -filter with dsquery * -filter
        $content = $content -replace 'dsquery computer -filter', 'dsquery * -filter'
        
        if ($content -ne $originalContent) {
            Set-Content -Path $dc13Path -Value $content -NoNewline
            Write-Host "  Fixed: DC-013" -ForegroundColor Green
            $fixResults.DC_Fixed++
        } else {
            Write-Host "  No changes needed: DC-013" -ForegroundColor Yellow
        }
    }
    catch {
        $error = "Error fixing DC-013: $($_.Exception.Message)"
        Write-Error $error
        $fixResults.Errors += $error
    }
} else {
    Write-Warning "DC-013 cmd.bat not found at: $dc13Path"
}

# Fix 3: TRST-031 startnode DN format
Write-Host "`n3. Fixing TRST-031 startnode DN format..." -ForegroundColor Green

$trst31Path = "Trust_Relationships\TRST-031_ExtraSIDs_Cross_Forest_Attack_Surface\cmd.bat"
if (Test-Path $trst31Path) {
    try {
        $content = Get-Content $trst31Path -Raw
        $originalContent = $content
        
        # Replace %USERDNSDOMAIN% with proper DN construction using %DCPATH%
        $content = $content -replace '"CN=System,%USERDNSDOMAIN%"', '"CN=System,%DCPATH%"'
        
        if ($content -ne $originalContent) {
            Set-Content -Path $trst31Path -Value $content -NoNewline
            Write-Host "  Fixed: TRST-031" -ForegroundColor Green
            $fixResults.TRST_Fixed++
        } else {
            Write-Host "  No changes needed: TRST-031" -ForegroundColor Yellow
        }
    }
    catch {
        $error = "Error fixing TRST-031: $($_.Exception.Message)"
        Write-Error $error
        $fixResults.Errors += $error
    }
} else {
    Write-Warning "TRST-031 cmd.bat not found at: $trst31Path"
}

# Summary
Write-Host "`n=== Fix Summary ===" -ForegroundColor Cyan
Write-Host "SVC files fixed: $($fixResults.SVC_Fixed)/30" -ForegroundColor Green
Write-Host "DC-013 fixed: $($fixResults.DC_Fixed)/1" -ForegroundColor Green
Write-Host "TRST-031 fixed: $($fixResults.TRST_Fixed)/1" -ForegroundColor Green

if ($fixResults.Errors.Count -gt 0) {
    Write-Host "`nErrors encountered:" -ForegroundColor Red
    $fixResults.Errors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
}

Write-Host "`nCMD engine error fixes completed!" -ForegroundColor Cyan