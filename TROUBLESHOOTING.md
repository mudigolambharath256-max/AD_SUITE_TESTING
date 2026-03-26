# 🔧 Troubleshooting Guide

## Issue: Output Shows Metadata Instead of Actual AD Object Properties

### Problem Description
When running checks, the output shows columns like:
- CheckId
- CheckName
- SourcePath
- WhenCreated

But MISSING the actual AD object properties like:
- name
- distinguishedName
- samAccountName
- userAccountControl

### Root Cause
The console width is too narrow to display all columns. PowerShell's `Format-Table -AutoSize` truncates columns that don't fit, and the metadata columns appear first, pushing the important AD properties off-screen.

### Solutions

#### Solution 1: Use CompactOutput Parameter (RECOMMENDED)
```powershell
# Show only AD object properties, hide metadata
.\adsi.ps1 -CheckId ACC-001 -CompactOutput
```

This will display ONLY the AD object properties:
```
name           distinguishedName                    samAccountName adminCount userAccountControl
----           -----------------                    -------------- ---------- ------------------
Administrator  CN=Administrator,CN=Users,DC=...     Administrator  1          512
krbtgt         CN=krbtgt,CN=Users,DC=...            krbtgt         1          514
```

#### Solution 2: Use PassThru and Select Specific Properties
```powershell
# Get objects and select only what you need
.\adsi.ps1 -CheckId ACC-001 -PassThru | Select-Object name, samAccountName, distinguishedName | Format-Table -AutoSize
```

#### Solution 3: Export to CSV and View in Excel
```powershell
# Export all columns to CSV
.\adsi.ps1 -CheckId ACC-001 -PassThru | Export-Csv results.csv -NoTypeInformation

# Open in Excel or view with Import-Csv
Import-Csv results.csv | Format-Table -AutoSize
```

#### Solution 4: Use Format-List Instead of Format-Table
```powershell
# Show all properties in list format
.\adsi.ps1 -CheckId ACC-001 -PassThru | Format-List *
```

#### Solution 5: Increase Console Width
```powershell
# Increase buffer width (temporary)
$host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size(300, 3000)

# Then run the check
.\adsi.ps1 -CheckId ACC-001
```

#### Solution 6: Use Out-GridView (Interactive)
```powershell
# Open results in interactive grid view
.\adsi.ps1 -CheckId ACC-001 -PassThru | Out-GridView
```

### What Changed in the Fix

The script now outputs columns in this order:

**BEFORE (Old Order):**
1. CheckId
2. CheckName
3. FindingCount
4. Result
5. SourcePath
6. name ← (Often truncated)
7. distinguishedName ← (Often truncated)
8. samAccountName ← (Often truncated)

**AFTER (New Order):**
1. name ← (Now visible!)
2. distinguishedName ← (Now visible!)
3. samAccountName ← (Now visible!)
4. adminCount ← (Now visible!)
5. userAccountControl ← (Now visible!)
6. CheckId
7. CheckName
8. FindingCount
9. Result
10. SourcePath

---

## Issue: LDAP Query Failed - Unknown Error (0x80005000)

### Problem
```
LDAP query failed: Exception calling "FindAll" with "0" argument(s): "Unknown error (0x80005000)"
```

### Causes & Solutions

#### Cause 1: Not Domain-Joined or No Domain Connectivity
**Solution:**
```powershell
# Test domain connectivity
Test-NetConnection dc01.domain.local -Port 389

# Specify ServerName explicitly
.\adsi.ps1 -CheckId ACC-001 -ServerName dc01.domain.local
```

#### Cause 2: Authentication Issues
**Solution:**
```powershell
# Run PowerShell as domain user
runas /user:DOMAIN\username powershell

# Or use alternate credentials
$cred = Get-Credential
Start-Process powershell -Credential $cred -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File .\adsi.ps1 -CheckId ACC-001"
```

#### Cause 3: Firewall Blocking LDAP (Port 389/636)
**Solution:**
```powershell
# Test LDAP port
Test-NetConnection dc01.domain.local -Port 389
Test-NetConnection dc01.domain.local -Port 636

# Check Windows Firewall
Get-NetFirewallRule | Where-Object { $_.DisplayName -like "*LDAP*" }
```

---

## Issue: Unknown CheckId

### Problem
```
Unknown CheckId: ACC-999
```

### Solution
```powershell
# List all available checks
$config = Get-Content .\checks.generated.json | ConvertFrom-Json
$config.checks | Select-Object id, name, category | Format-Table -AutoSize

# Search for specific check
$config.checks | Where-Object { $_.name -like "*Kerberos*" } | Select-Object id, name

# Verify specific CheckId exists
$config.checks | Where-Object { $_.id -eq 'ACC-001' }
```

---

## Issue: Module Not Found

### Problem
```
Module not found: .\Modules\ADSuite.Adsi.psm1
```

### Solution
```powershell
# Verify current directory
Get-Location

# Should be in AD_SUITE_TESTING directory
cd AD_SUITE_TESTING

# Verify module exists
Test-Path .\Modules\ADSuite.Adsi.psm1

# If missing, re-clone repository
git clone -b mod https://github.com/mudigolambharath256-max/AD_SUITE_TESTING.git
```

---

## Issue: Execution Policy Error

### Problem
```
.\adsi.ps1 : File cannot be loaded because running scripts is disabled on this system.
```

### Solution
```powershell
# Set execution policy for current session (recommended)
Set-ExecutionPolicy Bypass -Scope Process -Force

# Verify it's set
Get-ExecutionPolicy

# Alternative: Run with -ExecutionPolicy parameter
powershell -ExecutionPolicy Bypass -File .\adsi.ps1 -CheckId ACC-001
```

---

## Issue: No Findings But Expected Results

### Problem
Check returns "No findings" but you expect to see results (e.g., Domain Admins should have members).

### Causes & Solutions

#### Cause 1: Wrong Search Base
Some checks search Configuration or Schema instead of Domain.

**Solution:**
```powershell
# Check the searchBase in the check definition
$config = Get-Content .\checks.generated.json | ConvertFrom-Json
$check = $config.checks | Where-Object { $_.id -eq 'ACC-001' }
$check.searchBase  # Should show: Domain, Configuration, Schema, etc.
```

#### Cause 2: LDAP Filter Too Restrictive
The filter might exclude objects you expect to see.

**Solution:**
```powershell
# View the LDAP filter
$config = Get-Content .\checks.generated.json | ConvertFrom-Json
$check = $config.checks | Where-Object { $_.id -eq 'ACC-001' }
$check.ldapFilter

# Test with a simpler filter manually
```

#### Cause 3: UserAccountControl Filtering
Post-query UAC filtering might be excluding results.

**Solution:**
```powershell
# Check for UAC filtering
$check.userAccountControlMustInclude
$check.userAccountControlMustExclude
```

---

## Issue: Results Show "N/A" for Properties

### Problem
Output shows "N/A" for some or all AD properties.

### Causes & Solutions

#### Cause 1: Property Not Present on Object
The AD object doesn't have that attribute set.

**Solution:** This is expected behavior. "N/A" means the attribute is not set.

#### Cause 2: Property Not in PropertiesToLoad
The property wasn't requested in the LDAP query.

**Solution:**
```powershell
# Check propertiesToLoad
$config = Get-Content .\checks.generated.json | ConvertFrom-Json
$check = $config.checks | Where-Object { $_.id -eq 'ACC-001' }
$check.propertiesToLoad

# If missing, add it to checks.json or checks.generated.json
```

#### Cause 3: Insufficient Permissions
You don't have permission to read that attribute.

**Solution:**
```powershell
# Run as domain admin or user with appropriate permissions
runas /user:DOMAIN\admin powershell
```

---

## Issue: Slow Performance

### Problem
Checks take a long time to execute (>10 seconds).

### Causes & Solutions

#### Cause 1: Large Result Set
Query returns thousands of objects.

**Solution:**
```powershell
# Check result count first
.\adsi.ps1 -CheckId ACC-001 -PassThru | Measure-Object

# Use more specific filters or limit scope
```

#### Cause 2: Network Latency
High latency to domain controller.

**Solution:**
```powershell
# Test latency
Test-NetConnection dc01.domain.local

# Use closer DC
.\adsi.ps1 -CheckId ACC-001 -ServerName local-dc.domain.local
```

#### Cause 3: PageSize Too Small
Default pageSize is 1000, might need adjustment.

**Solution:** Edit checks.json to increase pageSize:
```json
{
  "defaults": {
    "pageSize": 5000
  }
}
```

---

## Issue: Unicode Characters in Output

### Problem
Output shows `\u0026` instead of `&` in LDAP filters.

### Solution
This was fixed in the Export-ChecksJsonFromLegacyScripts.ps1 tool. Regenerate checks.generated.json:

```powershell
.\tools\Export-ChecksJsonFromLegacyScripts.ps1 -LegacyRoot "C:\Path\To\Legacy\Scripts"
```

---

## Issue: Git Clone Fails

### Problem
```
fatal: unable to access 'https://github.com/...': Could not resolve host
```

### Solutions

#### Solution 1: Check Internet Connection
```powershell
Test-NetConnection github.com -Port 443
```

#### Solution 2: Use SSH Instead of HTTPS
```powershell
git clone git@github.com:mudigolambharath256-max/AD_SUITE_TESTING.git
```

#### Solution 3: Configure Proxy (if behind corporate proxy)
```powershell
git config --global http.proxy http://proxy.company.com:8080
```

---

## Best Practices to Avoid Issues

### 1. Always Use CompactOutput for Console Display
```powershell
.\adsi.ps1 -CheckId ACC-001 -CompactOutput
```

### 2. Use PassThru for Automation
```powershell
$results = .\adsi.ps1 -CheckId ACC-001 -PassThru
$results | Export-Csv results.csv -NoTypeInformation
```

### 3. Specify ServerName for Consistency
```powershell
.\adsi.ps1 -CheckId ACC-001 -ServerName dc01.domain.local
```

### 4. Use Quiet Mode in Scripts
```powershell
.\adsi.ps1 -CheckId ACC-001 -Quiet -PassThru
```

### 5. Check Exit Codes in Automation
```powershell
.\adsi.ps1 -CheckId ACC-001 -FailOnFindings
if ($LASTEXITCODE -eq 3) {
    Write-Host "Security issues found!"
}
```

---

## Getting Help

### View Built-in Help
```powershell
Get-Help .\adsi.ps1 -Full
Get-Help .\Test-RealWorldScenario.ps1 -Full
```

### Check Documentation
```powershell
Get-Content .\QUICK_START_GUIDE.md
Get-Content .\REAL_WORLD_SCENARIO_TEST.md
Get-Content .\EXECUTION_SUMMARY.md
```

### Debug Mode
```powershell
# Enable verbose output
$VerbosePreference = 'Continue'
.\adsi.ps1 -CheckId ACC-001 -Verbose

# Enable debug output
$DebugPreference = 'Continue'
.\adsi.ps1 -CheckId ACC-001 -Debug
```

---

## Quick Reference: Common Commands

```powershell
# Show only AD properties (no metadata)
.\adsi.ps1 -CheckId ACC-001 -CompactOutput

# Export to CSV
.\adsi.ps1 -CheckId ACC-001 -PassThru | Export-Csv results.csv -NoTypeInformation

# Interactive grid view
.\adsi.ps1 -CheckId ACC-001 -PassThru | Out-GridView

# List format (all properties)
.\adsi.ps1 -CheckId ACC-001 -PassThru | Format-List *

# Select specific properties
.\adsi.ps1 -CheckId ACC-001 -PassThru | Select-Object name, samAccountName, distinguishedName

# Silent mode with exit code check
.\adsi.ps1 -CheckId ACC-001 -Quiet -FailOnFindings
if ($LASTEXITCODE -eq 3) { Write-Host "Issues found!" }
```

---

## Still Having Issues?

1. Verify you're in the correct directory: `Get-Location`
2. Check PowerShell version: `$PSVersionTable.PSVersion` (needs 5.1+)
3. Verify all files exist: `Get-ChildItem`
4. Test LDAP connectivity: `[ADSI]"LDAP://RootDSE"`
5. Check execution policy: `Get-ExecutionPolicy`
6. Review error messages carefully
7. Try with `-Verbose` flag for detailed output

**Repository:** https://github.com/mudigolambharath256-max/AD_SUITE_TESTING  
**Branch:** mod
