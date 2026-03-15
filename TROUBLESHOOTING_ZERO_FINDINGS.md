# Troubleshooting: Zero Findings on Scan

## Common Causes and Solutions

### 1. Machine Not Domain-Joined (Most Common)

**Symptom:** All scans return 0 findings

**Cause:** The ADSI scripts require the machine to be joined to an Active Directory domain.

**Solution:**
```powershell
# Check if machine is domain-joined
$cs = Get-WmiObject -Class Win32_ComputerSystem
if ($cs.PartOfDomain) {
    Write-Host "Domain: $($cs.Domain)" -ForegroundColor Green
} else {
    Write-Host "NOT domain-joined!" -ForegroundColor Red
}
```

**If not domain-joined:**
- Join the machine to your AD domain
- Or run the application on a domain-joined machine
- Or use the "Target Configuration" to specify a domain controller

---

### 2. Incorrect Suite Root Path

**Symptom:** Scans fail or return 0 findings

**Check the path in Settings:**
1. Go to Settings page
2. Check "Suite Root Path"
3. Should point to the folder containing category folders like:
   - `Access_Control/`
   - `Authentication/`
   - `Domain_Controllers/`
   - etc.

**Correct path examples:**
```
C:\Users\acer\Downloads\AD_suiteXXX
C:\ADSuite\AD-Suite-scripts-main
```

**Test the path:**
```powershell
# Check if path exists and has categories
$path = "C:\Users\acer\Downloads\AD_suiteXXX"
Test-Path $path
Get-ChildItem $path -Directory | Select-Object Name
```

---

### 3. No Vulnerable Objects Found (Actually Correct!)

**Symptom:** Scans complete successfully but show 0 findings

**This might be correct!** If your AD environment is secure, many checks will return 0 findings.

**To verify:**
Run a test check manually:
```powershell
cd C:\Users\acer\Downloads\AD_suiteXXX\Access_Control\ACC-001_Privileged_Users_adminCount1
.\adsi.ps1
```

If it returns results, the scripts work. If it returns nothing, your domain might not have privileged users with adminCount=1.

---

### 4. LDAP Connection Issues

**Test LDAP connectivity:**
```powershell
# Test connection to domain
try {
    $root = [ADSI]'LDAP://RootDSE'
    $nc = $root.defaultNamingContext.ToString()
    Write-Host "Connected! Domain NC: $nc" -ForegroundColor Green
} catch {
    Write-Host "LDAP connection failed: $_" -ForegroundColor Red
}
```

---

## Diagnostic Steps

### Step 1: Run Diagnostic Endpoint

Open in browser:
```
http://localhost:3001/api/scan/diagnose?suiteRoot=C:\Users\acer\Downloads\AD_suiteXXX
```

This will show:
- If suite root exists
- How many checks were discovered
- If a test check can be resolved

---

### Step 2: Test a Single Check Manually

```powershell
# Navigate to a check directory
cd C:\Users\acer\Downloads\AD_suiteXXX\Authentication\AUTH-001_Accounts_Without_Kerberos_Pre-Auth

# Run the ADSI script
.\adsi.ps1

# Check output
# If you see JSON output with objects, it works!
# If you see nothing, either:
#   - No vulnerable accounts exist (good!)
#   - LDAP connection failed (bad)
```

---

### Step 3: Check PowerShell Execution Policy

```powershell
Get-ExecutionPolicy

# If it's "Restricted", change it:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

### Step 4: Verify Script Output Format

The scripts should output JSON. Check a script:
```powershell
cd C:\Users\acer\Downloads\AD_suiteXXX\Access_Control\ACC-001_Privileged_Users_adminCount1

# Run and pipe to JSON
.\adsi.ps1 | ConvertTo-Json -Depth 10
```

---

## Quick Fix Script

Save as `test-scan-setup.ps1`:

```powershell
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
```

Run this script:
```powershell
.\test-scan-setup.ps1
```

---

## Understanding "0 Findings"

**Zero findings can be GOOD or BAD:**

### GOOD (Secure Environment):
- No accounts with weak passwords
- No accounts with Kerberos pre-auth disabled
- No privileged accounts that can be delegated
- Your AD is properly secured!

### BAD (Configuration Issue):
- Scripts can't connect to AD
- Suite root path is wrong
- Machine not domain-joined
- LDAP queries failing

**How to tell the difference:**
1. Check the scan logs in the UI
2. Look for error messages
3. Run a manual test (see Step 2 above)

---

## Still Having Issues?

### Enable Debug Mode

Edit `.env` file:
```env
NODE_ENV=development
LOG_LEVEL=debug
```

Restart the backend:
```powershell
cd ad-suite-web\backend
node server.js
```

Check the console output for detailed error messages.

---

### Check Backend Logs

Look at the terminal where you started the backend. You should see:
```
[SCAN <scanId>] Starting scan with X checks using adsi engine
[SCAN <scanId>] Resolved AUTH-001 to: C:\...\adsi.ps1
[SCAN <scanId>] Executing: powershell.exe -ExecutionPolicy Bypass...
```

If you see errors here, that's your clue!

---

### Test with a Known-Vulnerable Check

Try running a check that SHOULD return results:

```powershell
# This check lists ALL users (should always have results)
cd C:\Users\acer\Downloads\AD_suiteXXX\Users_Accounts\USR-014_Accounts_with_Never_Expiring_Passwords
.\adsi.ps1
```

If this returns nothing, your LDAP connection is definitely broken.

---

## Common Error Messages

### "Cannot connect to Active Directory"
- Machine not domain-joined
- LDAP service not running
- Firewall blocking LDAP (port 389/636)

### "Script not found for check"
- Suite root path is incorrect
- Check ID doesn't exist
- Engine type mismatch (trying to run .ps1 with cmd engine)

### "Process exited with code 1"
- PowerShell execution policy blocking
- Script syntax error
- Missing permissions

---

## Need More Help?

1. Check the browser console (F12) for JavaScript errors
2. Check the backend terminal for detailed logs
3. Run the diagnostic endpoint: `/api/scan/diagnose`
4. Test LDAP manually with the PowerShell commands above
5. Verify the suite root path contains the correct folder structure

---

**Remember:** Zero findings might be correct! A well-secured AD environment will have few or no findings for many checks.
