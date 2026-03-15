# Test Scan Setup Script
Write-Host "=== AD Security Suite - Scan Setup Test ===" -ForegroundColor Cyan

# 1. Check domain membership
Write-Host "`n[1/5] Checking domain membership..." -ForegroundColor Yellow
$cs = Get-WmiObject -Class Win32_ComputerSystem
if ($cs.PartOfDomain) {
    Write-Host "  OK: Joined to domain: $($cs.Domain)" -ForegroundColor Green
} else {
    Write-Host "  FAIL: Machine is NOT domain-joined!" -ForegroundColor Red
    Write-Host "  Solution: Join this machine to your AD domain" -ForegroundColor Yellow
}

# 2. Test LDAP connection
Write-Host "`n[2/5] Testing LDAP connection..." -ForegroundColor Yellow
try {
    $root = [ADSI]'LDAP://RootDSE'
    $nc = $root.defaultNamingContext.ToString()
    Write-Host "  OK: Connected to domain: $nc" -ForegroundColor Green
} catch {
    Write-Host "  FAIL: Cannot connect to LDAP: $_" -ForegroundColor Red
}

# 3. Check suite root path
Write-Host "`n[3/5] Checking suite root path..." -ForegroundColor Yellow
$suiteRoot = "C:\Users\acer\Downloads\AD_suiteXXX"
if (Test-Path $suiteRoot) {
    $categories = Get-ChildItem $suiteRoot -Directory | Where-Object { $_.Name -match '^[A-Z]' }
    Write-Host "  OK: Suite root exists with $($categories.Count) categories" -ForegroundColor Green
} else {
    Write-Host "  FAIL: Suite root not found: $suiteRoot" -ForegroundColor Red
    Write-Host "  Solution: Update the path in Settings" -ForegroundColor Yellow
}

# 4. Test a single check
Write-Host "`n[4/5] Testing a single check..." -ForegroundColor Yellow
$testCheck = Join-Path $suiteRoot "Authentication\AUTH-001_Accounts_Without_Kerberos_Pre-Auth\adsi.ps1"
if (Test-Path $testCheck) {
    Write-Host "  Running: $testCheck" -ForegroundColor Gray
    $output = & $testCheck 2>&1
    if ($output) {
        Write-Host "  OK: Script produced output" -ForegroundColor Green
        Write-Host "  Output length: $($output.Length) characters" -ForegroundColor Gray
    } else {
        Write-Host "  INFO: Script ran but returned no results" -ForegroundColor Yellow
        Write-Host "  This is normal if no vulnerable accounts exist" -ForegroundColor Gray
    }
} else {
    Write-Host "  FAIL: Test check not found" -ForegroundColor Red
}

# 5. Check PowerShell version
Write-Host "`n[5/5] Checking PowerShell version..." -ForegroundColor Yellow
$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -ge 5) {
    Write-Host "  OK: PowerShell $($psVersion.Major).$($psVersion.Minor)" -ForegroundColor Green
} else {
    Write-Host "  WARN: PowerShell $($psVersion.Major).$($psVersion.Minor) - recommend 5.1+" -ForegroundColor Yellow
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan
