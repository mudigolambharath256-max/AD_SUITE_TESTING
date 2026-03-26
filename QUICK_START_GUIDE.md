# 🚀 AD Suite - Quick Start Guide

## Complete Commands to Clone and Execute in PowerShell

---

## 📥 Step 1: Clone the Repository

### Option A: Clone via HTTPS
```powershell
# Clone the repository
git clone https://github.com/mudigolambharath256-max/AD_SUITE_TESTING.git

# Navigate into the directory
cd AD_SUITE_TESTING

# Switch to mod branch
git checkout mod
```

### Option B: Clone specific branch directly
```powershell
# Clone only the mod branch
git clone -b mod https://github.com/mudigolambharath256-max/AD_SUITE_TESTING.git

# Navigate into the directory
cd AD_SUITE_TESTING
```

### Option C: Clone to specific location
```powershell
# Clone to C:\Tools\AD_SUITE
git clone https://github.com/mudigolambharath256-max/AD_SUITE_TESTING.git C:\Tools\AD_SUITE

# Navigate to the directory
cd C:\Tools\AD_SUITE

# Switch to mod branch
git checkout mod
```

---

## ⚙️ Step 2: Set Execution Policy

### For Current Session Only (Recommended)
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
```

### For Current User (Persists)
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force
```

### For Entire Machine (Requires Admin)
```powershell
# Run PowerShell as Administrator first
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope LocalMachine -Force
```

---

## 🔍 Step 3: Verify Installation

```powershell
# List all files
Get-ChildItem

# Verify key files exist
Test-Path .\adsi.ps1
Test-Path .\checks.json
Test-Path .\checks.generated.json
Test-Path .\Modules\ADSuite.Adsi.psm1

# Check PowerShell version (requires 5.1+)
$PSVersionTable.PSVersion
```

---

## 🎯 Step 4: Execute Single Check

### Basic Execution (Local Domain)
```powershell
.\adsi.ps1 -CheckId ACC-001
```

### Against Specific Domain Controller
```powershell
.\adsi.ps1 -CheckId ACC-001 -ServerName dc01.domain.local
```

### Against GOAD Lab
```powershell
.\adsi.ps1 -CheckId ACC-001 -ServerName kingslanding.sevenkingdoms.local
```

---

## 🔥 Step 5: Popular Security Checks

### Kerberos Attacks
```powershell
# AS-REP Roastable Accounts (brandon.stark in GOAD)
.\adsi.ps1 -CheckId KRB-002 -ServerName kingslanding.sevenkingdoms.local

# Kerberoastable Accounts (sql_svc, http_svc in GOAD)
.\adsi.ps1 -CheckId ACC-034 -ServerName kingslanding.sevenkingdoms.local

# Unconstrained Delegation
.\adsi.ps1 -CheckId ACC-027 -ServerName kingslanding.sevenkingdoms.local

# Constrained Delegation
.\adsi.ps1 -CheckId ACC-028 -ServerName kingslanding.sevenkingdoms.local

# Resource-Based Constrained Delegation (RBCD)
.\adsi.ps1 -CheckId ACC-039 -ServerName kingslanding.sevenkingdoms.local
```

### Privileged Access
```powershell
# Privileged Users (adminCount=1)
.\adsi.ps1 -CheckId ACC-001 -ServerName kingslanding.sevenkingdoms.local

# Domain Admins Group Members
.\adsi.ps1 -CheckId ACC-014 -ServerName kingslanding.sevenkingdoms.local

# Enterprise Admins Group Members
.\adsi.ps1 -CheckId ACC-015 -ServerName kingslanding.sevenkingdoms.local

# Backup Operators
.\adsi.ps1 -CheckId ACC-017 -ServerName kingslanding.sevenkingdoms.local

# DNS Admins
.\adsi.ps1 -CheckId ACC-021 -ServerName kingslanding.sevenkingdoms.local
```

### Certificate Services (ADCS Attacks)
```powershell
# ESC1 - Templates Allowing SAN Specification
.\adsi.ps1 -CheckId CERT-002 -ServerName kingslanding.sevenkingdoms.local

# ESC2 - Templates with Any Purpose EKU
.\adsi.ps1 -CheckId CERT-003 -ServerName kingslanding.sevenkingdoms.local

# ESC3 - Certificate Request Agent
.\adsi.ps1 -CheckId CERT-004 -ServerName kingslanding.sevenkingdoms.local

# ESC4 - Weak Access Control
.\adsi.ps1 -CheckId CERT-005 -ServerName kingslanding.sevenkingdoms.local
```

### Advanced Attacks
```powershell
# Shadow Credentials Detection
.\adsi.ps1 -CheckId ACC-037 -ServerName kingslanding.sevenkingdoms.local

# Users with SIDHistory
.\adsi.ps1 -CheckId ACC-004 -ServerName kingslanding.sevenkingdoms.local

# DCSync Rights
.\adsi.ps1 -CheckId ACC-033 -ServerName kingslanding.sevenkingdoms.local
```

---

## 📊 Step 6: Batch Execution

### Execute Multiple Checks
```powershell
# Define checks to run
$checks = @('ACC-001', 'ACC-014', 'ACC-034', 'KRB-002', 'ACC-037')

# Execute each check
foreach ($checkId in $checks) {
    Write-Host "`n=== Running $checkId ===" -ForegroundColor Cyan
    .\adsi.ps1 -CheckId $checkId -ServerName kingslanding.sevenkingdoms.local
}
```

### Execute with Results Export
```powershell
# Create results directory
New-Item -ItemType Directory -Path .\Results -Force

# Define checks
$checks = @('ACC-001', 'ACC-014', 'ACC-034', 'KRB-002', 'ACC-037')

# Execute and export
foreach ($checkId in $checks) {
    Write-Host "Running $checkId..." -ForegroundColor Yellow
    $results = .\adsi.ps1 -CheckId $checkId -ServerName kingslanding.sevenkingdoms.local -PassThru
    
    if ($results) {
        $outputFile = ".\Results\$checkId`_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        $results | Export-Csv -Path $outputFile -NoTypeInformation
        Write-Host "  [+] Exported to: $outputFile" -ForegroundColor Green
    }
}
```

---

## 🤖 Step 7: Automated Test Execution

### Run Full Scenario Test (10 Checks)
```powershell
# Execute automated test script
.\Test-RealWorldScenario.ps1 -ServerName kingslanding.sevenkingdoms.local

# With verbose output
.\Test-RealWorldScenario.ps1 -ServerName kingslanding.sevenkingdoms.local -Verbose

# With detailed trace
.\Test-RealWorldScenario.ps1 -ServerName kingslanding.sevenkingdoms.local -DetailedTrace

# Custom output directory
.\Test-RealWorldScenario.ps1 -ServerName kingslanding.sevenkingdoms.local -OutputDir "C:\AuditResults"
```

---

## 🔄 Step 8: CI/CD Integration

### Test with FailOnFindings (Exit Code 3 on Findings)
```powershell
# Single check with CI/CD mode
.\adsi.ps1 -CheckId KRB-002 -ServerName kingslanding.sevenkingdoms.local -Quiet -FailOnFindings

# Check exit code
if ($LASTEXITCODE -eq 0) {
    Write-Host "[PASS] No security issues detected" -ForegroundColor Green
} elseif ($LASTEXITCODE -eq 3) {
    Write-Host "[FAIL] Security issues found!" -ForegroundColor Red
    exit 1
} else {
    Write-Host "[ERROR] Execution error (code $LASTEXITCODE)" -ForegroundColor Magenta
    exit 1
}
```

### Automated Security Gate
```powershell
# Define critical checks
$criticalChecks = @('KRB-002', 'ACC-034', 'ACC-037', 'CERT-002')

$failedChecks = @()

foreach ($check in $criticalChecks) {
    Write-Host "Testing $check..." -ForegroundColor Yellow
    .\adsi.ps1 -CheckId $check -ServerName kingslanding.sevenkingdoms.local -Quiet -FailOnFindings
    
    if ($LASTEXITCODE -eq 3) {
        Write-Host "  [FAIL] $check found security issues!" -ForegroundColor Red
        $failedChecks += $check
    } elseif ($LASTEXITCODE -eq 0) {
        Write-Host "  [PASS] $check - No issues" -ForegroundColor Green
    }
}

if ($failedChecks.Count -gt 0) {
    Write-Host "`n[SECURITY GATE FAILED]" -ForegroundColor Red
    Write-Host "Failed checks: $($failedChecks -join ', ')" -ForegroundColor Red
    exit 1
} else {
    Write-Host "`n[SECURITY GATE PASSED]" -ForegroundColor Green
    exit 0
}
```

---

## 📋 Step 9: View Available Checks

### List All Checks
```powershell
# Load configuration
$config = Get-Content .\checks.generated.json | ConvertFrom-Json

# Display total count
Write-Host "Total Checks: $($config.checks.Count)" -ForegroundColor Cyan

# List all checks
$config.checks | Select-Object id, name, category | Format-Table -AutoSize
```

### List Checks by Category
```powershell
# Load configuration
$config = Get-Content .\checks.generated.json | ConvertFrom-Json

# Group by category
$categories = $config.checks | Group-Object category | Sort-Object Count -Descending

# Display
$categories | Select-Object @{N='Category';E={$_.Name}}, Count | Format-Table -AutoSize
```

### Search for Specific Checks
```powershell
# Load configuration
$config = Get-Content .\checks.generated.json | ConvertFrom-Json

# Search by keyword
$keyword = "Kerberos"
$config.checks | Where-Object { $_.name -like "*$keyword*" } | 
    Select-Object id, name, category | Format-Table -AutoSize

# Search by category
$category = "Kerberos_Security"
$config.checks | Where-Object { $_.category -eq $category } | 
    Select-Object id, name | Format-Table -AutoSize
```

---

## 🎯 Step 10: GOAD Lab Complete Audit

### Comprehensive GOAD Audit Script
```powershell
# Create audit script
$auditScript = @'
#requires -Version 5.1
param(
    [string]$Domain = "sevenkingdoms.local",
    [string]$ServerName = "kingslanding.sevenkingdoms.local"
)

Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  GOAD Lab Security Audit                                      ║" -ForegroundColor Cyan
Write-Host "║  Domain: $Domain                                              ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

# High-value checks for GOAD
$checks = @{
    'ACC-001' = 'Privileged Users (adminCount=1)'
    'ACC-004' = 'Users with SIDHistory'
    'ACC-006' = 'Computers with RBCD'
    'ACC-014' = 'Domain Admins'
    'ACC-015' = 'Enterprise Admins'
    'ACC-034' = 'Kerberoastable Accounts'
    'ACC-037' = 'Shadow Credentials'
    'ACC-039' = 'RBCD Detection'
    'KRB-002' = 'AS-REP Roastable'
    'CERT-002' = 'ESC1 Templates'
    'CERT-005' = 'ESC4 Templates'
}

$results = @()
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'

foreach ($checkId in $checks.Keys) {
    $checkName = $checks[$checkId]
    Write-Host "`n[*] $checkId - $checkName" -ForegroundColor Yellow
    
    try {
        $output = .\adsi.ps1 -CheckId $checkId -ServerName $ServerName -PassThru
        
        if ($output) {
            $count = @($output).Count
            Write-Host "    [+] Found $count findings" -ForegroundColor $(if ($count -gt 0) { 'Red' } else { 'Green' })
            $results += $output
        } else {
            Write-Host "    [-] No findings" -ForegroundColor Green
        }
    } catch {
        Write-Host "    [!] Error: $_" -ForegroundColor Red
    }
}

# Export results
$outputDir = ".\GOAD_Audit_$timestamp"
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

if ($results.Count -gt 0) {
    $results | Export-Csv -Path "$outputDir\All_Findings.csv" -NoTypeInformation
    Write-Host "`n[+] Results exported to: $outputDir\All_Findings.csv" -ForegroundColor Green
}

Write-Host "`n[+] Audit complete!" -ForegroundColor Green
'@

# Save script
$auditScript | Out-File -FilePath ".\Audit-GOAD.ps1" -Encoding UTF8

# Execute audit
.\Audit-GOAD.ps1 -ServerName kingslanding.sevenkingdoms.local
```

---

## 🔧 Troubleshooting

### Issue 1: "File not found" or "Cannot find path"
```powershell
# Verify current directory
Get-Location

# Should be in AD_SUITE_TESTING directory
# If not, navigate to it:
cd AD_SUITE_TESTING
```

### Issue 2: "Execution policy" error
```powershell
# Set execution policy for current session
Set-ExecutionPolicy Bypass -Scope Process -Force

# Verify it's set
Get-ExecutionPolicy
```

### Issue 3: "Module not found"
```powershell
# Verify module exists
Test-Path .\Modules\ADSuite.Adsi.psm1

# Manually import module
Import-Module .\Modules\ADSuite.Adsi.psm1 -Force
```

### Issue 4: "LDAP connection failed"
```powershell
# Test LDAP connectivity
[ADSI]"LDAP://RootDSE"

# Test specific DC
[ADSI]"LDAP://kingslanding.sevenkingdoms.local/RootDSE"

# Check network connectivity
Test-NetConnection kingslanding.sevenkingdoms.local -Port 389
```

### Issue 5: "Unknown CheckId"
```powershell
# Verify check exists
$config = Get-Content .\checks.generated.json | ConvertFrom-Json
$config.checks | Where-Object { $_.id -eq 'ACC-001' }

# List all available checks
$config.checks | Select-Object id, name | Format-Table -AutoSize
```

---

## 📚 Additional Resources

### View Documentation
```powershell
# View scenario documentation
Get-Content .\REAL_WORLD_SCENARIO_TEST.md

# View execution summary
Get-Content .\EXECUTION_SUMMARY.md

# View this quick start guide
Get-Content .\QUICK_START_GUIDE.md
```

### Get Help
```powershell
# Get help for main script
Get-Help .\adsi.ps1 -Full

# Get help for test script
Get-Help .\Test-RealWorldScenario.ps1 -Full
```

---

## 🎓 Example Workflows

### Workflow 1: Quick Security Assessment
```powershell
# Clone and setup
git clone -b mod https://github.com/mudigolambharath256-max/AD_SUITE_TESTING.git
cd AD_SUITE_TESTING
Set-ExecutionPolicy Bypass -Scope Process -Force

# Run top 5 critical checks
$checks = @('ACC-001', 'ACC-034', 'KRB-002', 'ACC-037', 'CERT-002')
foreach ($c in $checks) { .\adsi.ps1 -CheckId $c -ServerName dc01.domain.local }
```

### Workflow 2: GOAD Lab Enumeration
```powershell
# Clone and setup
git clone -b mod https://github.com/mudigolambharath256-max/AD_SUITE_TESTING.git
cd AD_SUITE_TESTING
Set-ExecutionPolicy Bypass -Scope Process -Force

# Run automated test
.\Test-RealWorldScenario.ps1 -ServerName kingslanding.sevenkingdoms.local -Verbose
```

### Workflow 3: CI/CD Security Gate
```powershell
# Clone and setup
git clone -b mod https://github.com/mudigolambharath256-max/AD_SUITE_TESTING.git
cd AD_SUITE_TESTING
Set-ExecutionPolicy Bypass -Scope Process -Force

# Run critical checks with fail-on-findings
$critical = @('KRB-002', 'ACC-034', 'ACC-037')
foreach ($c in $critical) {
    .\adsi.ps1 -CheckId $c -ServerName dc01.domain.local -Quiet -FailOnFindings
    if ($LASTEXITCODE -eq 3) { exit 1 }
}
```

---

## ✅ Complete One-Liner Setup

### For Local Domain
```powershell
git clone -b mod https://github.com/mudigolambharath256-max/AD_SUITE_TESTING.git; cd AD_SUITE_TESTING; Set-ExecutionPolicy Bypass -Scope Process -Force; .\adsi.ps1 -CheckId ACC-001
```

### For GOAD Lab
```powershell
git clone -b mod https://github.com/mudigolambharath256-max/AD_SUITE_TESTING.git; cd AD_SUITE_TESTING; Set-ExecutionPolicy Bypass -Scope Process -Force; .\adsi.ps1 -CheckId KRB-002 -ServerName kingslanding.sevenkingdoms.local
```

### For Automated Test
```powershell
git clone -b mod https://github.com/mudigolambharath256-max/AD_SUITE_TESTING.git; cd AD_SUITE_TESTING; Set-ExecutionPolicy Bypass -Scope Process -Force; .\Test-RealWorldScenario.ps1 -ServerName kingslanding.sevenkingdoms.local
```

---

## 🎯 Summary

**Repository:** https://github.com/mudigolambharath256-max/AD_SUITE_TESTING  
**Branch:** mod  
**Total Checks:** 756 security checks  
**Categories:** 26 security categories  
**Requirements:** PowerShell 5.1+, Windows, .NET Framework  

**No external dependencies required - Pure ADSI implementation!**
