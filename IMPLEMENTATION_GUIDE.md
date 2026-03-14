# BloodHound Export Implementation Guide

**Based on**: Audit completed March 13, 2026  
**Status**: Ready for Phase 1 implementation  
**Estimated Time**: 10-20 hours total

---

## 📋 Prerequisites

Before starting, ensure you have:
- ✅ Completed audit (AUDIT_REPORT_BH_ELIGIBILITY_2026-03-13_102958.md)
- ✅ Reviewed executive summary (AUDIT_EXECUTIVE_SUMMARY.md)
- ✅ PowerShell 5.1 or higher
- ✅ Write access to all check directories
- ✅ Backup storage available (~500MB recommended)

---

## 🚀 Phase 1: Critical Blockers (REQUIRED)

**Goal**: Fix A1 and A2 issues to enable BloodHound export  
**Time**: 2-4 hours  
**Risk**: LOW

### Step 1.1: Dry Run Test

Test the fix script without making changes:

```powershell
.\fix-phase1-critical-blockers.ps1 -DryRun
```

**Expected Output**:
- Files to be modified: ~762
- A1 fixes: ~12
- A2 fixes: ~762

### Step 1.2: Apply Fixes

Run the fix script (creates automatic backups):

```powershell
.\fix-phase1-critical-blockers.ps1
```

**What it does**:
1. Creates backup directory with timestamp
2. Backs up each file before modification
3. Applies A1 fix: Stores FindAll() in $results variable
4. Applies A2 fix: Adds 'objectSid' to PropertiesToLoad
5. Generates fix report

### Step 1.3: Verify Fixes

Quick verification of random sample:

```powershell
.\verify-phase1-fixes.ps1 -SampleSize 20
```

**Expected**: 100% pass rate on sampled files

### Step 1.4: Re-run Full Audit

Verify all fixes across entire suite:

```powershell
.\audit-bloodhound-eligibility.ps1
```

**Expected Results**:
- A1 FAIL: 0 (was 12)
- A2 FAIL: 0 (was 762)
- Ready for export: YES

### Step 1.5: Manual Spot Check

Test a few modified scripts manually:

```powershell
# Test a user check
.\Access_Control\ACC-001_Privileged_Users_adminCount1\adsi.ps1

# Test a computer check
.\Computers_Servers\COMP-001_Computers_with_Unconstrained_Delegation\adsi.ps1

# Test a certificate check
.\Certificate_Services\CERT-002_ESC1_Templates_Allowing_SAN_Specification\adsi.ps1
```

**Verify**:
- Scripts run without errors
- Output includes objectSid values
- Results are stored in $results variable

---

## 🔧 Phase 2: High Priority Fixes (RECOMMENDED)

**Goal**: Fix B8, B9, B10 for combined and powershell scripts  
**Time**: 4-8 hours  
**Risk**: MEDIUM

### Fix B8: Add-Type Guard

**Files**: 739 combined_multiengine.ps1

**Pattern to find**:
```powershell
Add-Type -TypeDefinition $csharpCode
```

**Replace with**:
```powershell
if (-not ([System.Management.Automation.PSTypeName]'CheckRunner').Type) {
    Add-Type -TypeDefinition $csharpCode
}
```

### Fix B9: Public Class and Run Method

**Files**: 733 combined_multiengine.ps1

**Pattern to find**:
```csharp
class Program {
    static void Main() {
```

**Replace with**:
```csharp
public class CheckRunner {
    public static void Run() {
```

**Also add after Add-Type**:
```powershell
[CheckRunner]::Run()
```

### Fix B10: Add SearchBase

**Files**: 321 powershell.ps1

**Pattern to find**:
```powershell
Get-ADUser -Filter * -Properties *
```

**Replace with**:
```powershell
$domainDN = (Get-ADDomain).DistinguishedName
Get-ADUser -Filter * -Properties * -SearchBase $domainDN
```

---

## 📊 Phase 3: Quality Improvements (OPTIONAL)

**Goal**: Improve data quality  
**Time**: 2-4 hours  
**Risk**: LOW

### Fix B2: Add samAccountName

Similar to A2 fix, add 'samAccountName' to PropertiesToLoad arrays.

### Fix B4: Convert FILETIME

**Files**: 35 adsi.ps1

**Pattern to find**:
```powershell
pwdLastSet = if ($p['pwdlastset']) { $p['pwdlastset'][0] } else { 'N/A' }
```

**Replace with**:
```powershell
pwdLastSet = if ($p['pwdlastset'] -and $p['pwdlastset'][0] -gt 0) { 
    [DateTime]::FromFileTime($p['pwdlastset'][0]).ToString('yyyy-MM-dd HH:mm:ss')
} else { 'N/A' }
```

### Fix B7: SearchRoot for Non-Domain NC

**Files**: 310 adsi.ps1 (Certificate Services, some GPO/AUTH checks)

**For CERT-* checks**:
```powershell
$root = [ADSI]'LDAP://RootDSE'
$configNC = $root.configurationNamingContext.ToString()
$searcher.SearchRoot = [ADSI]"LDAP://$configNC"
```

---

## 🎯 Phase 4: Append BloodHound Export Block

**Goal**: Add export functionality to all scripts  
**Time**: 2-4 hours  
**Risk**: LOW (additive only)

### Export Block Template

Add this to the end of each adsi.ps1 (after results processing):

```powershell
# ============================================================================
# BloodHound Export Block
# ============================================================================
if ($env:ADSUITE_SESSION_ID) {
    $bhDir = Join-Path $env:TEMP "adsuite_bh_$env:ADSUITE_SESSION_ID"
    New-Item -ItemType Directory -Path $bhDir -Force | Out-Null
    
    $bhItems = @()
    foreach ($result in $results) {
        $props = $result.Properties
        
        # Extract SID
        $sidBytes = $props['objectsid'][0]
        $sid = if ($sidBytes) {
            try {
                (New-Object System.Security.Principal.SecurityIdentifier($sidBytes, 0)).Value
            } catch {
                $props['distinguishedname'][0]
            }
        } else {
            $props['distinguishedname'][0]
        }
        
        # Determine object type
        $objectType = 'Base'
        $classes = $props['objectclass']
        if ($classes -contains 'user' -and $classes -notcontains 'computer') {
            $objectType = 'User'
        } elseif ($classes -contains 'group') {
            $objectType = 'Group'
        } elseif ($classes -contains 'computer') {
            $objectType = 'Computer'
        } elseif ($classes -contains 'domain') {
            $objectType = 'Domain'
        }
        
        # Build BloodHound node
        $bhNode = @{
            ObjectIdentifier = $sid
            ObjectType = $objectType
            Properties = @{
                name = if ($props['samaccountname']) { 
                    "$($props['samaccountname'][0])@$env:USERDNSDOMAIN" 
                } else { 
                    $props['name'][0] 
                }
                distinguishedname = $props['distinguishedname'][0]
                domain = $env:USERDNSDOMAIN
                objectid = $sid
            }
            Aces = @()
            IsACLProtected = $false
        }
        
        $bhItems += $bhNode
    }
    
    # Write BloodHound JSON
    $bhOutput = @{
        meta = @{
            type = 'findings'
            count = $bhItems.Count
            version = 4
            check_id = 'CHECK_ID_HERE'
        }
        data = $bhItems
    }
    
    $bhFile = Join-Path $bhDir "CHECK_ID_HERE.json"
    $bhOutput | ConvertTo-Json -Depth 10 -Compress | Set-Content $bhFile -Encoding UTF8
    
    Write-Host "[BloodHound] Exported $($bhItems.Count) items to $bhFile" -ForegroundColor Green
}
```

### Automation Script

Create `append-bloodhound-export.ps1` to add export blocks to all scripts automatically.

---

## ✅ Testing & Validation

### Test Plan

1. **Unit Test**: Run individual scripts
   ```powershell
   $env:ADSUITE_SESSION_ID = "test123"
   .\Access_Control\ACC-001_Privileged_Users_adminCount1\adsi.ps1
   ```

2. **Verify JSON Output**:
   ```powershell
   $json = Get-Content "$env:TEMP\adsuite_bh_test123\ACC-001.json" | ConvertFrom-Json
   $json.data[0].ObjectIdentifier  # Should be a SID
   $json.data[0].Properties.name   # Should be ACCOUNT@DOMAIN
   ```

3. **BloodHound Import Test**:
   - Copy JSON files to BloodHound ingestion directory
   - Verify nodes appear in BloodHound UI
   - Check node properties are populated
   - Verify relationships are correct

4. **Full Suite Test**:
   ```powershell
   # Run all checks with export enabled
   $env:ADSUITE_SESSION_ID = "full_test_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
   # Execute suite runner
   ```

---

## 🔄 Rollback Procedure

If issues occur:

### Rollback Phase 1 Fixes

```powershell
# Restore from backup
$backupDir = "backups_YYYYMMDD_HHMMSS"  # Use actual backup directory
Get-ChildItem $backupDir -Recurse -File | ForEach-Object {
    $targetPath = $_.FullName -replace [regex]::Escape($backupDir), ''
    Copy-Item $_.FullName $targetPath -Force
}
```

### Remove Export Blocks

```powershell
# Remove export blocks from all files
Get-ChildItem -Recurse -Filter "adsi.ps1" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    $content = $content -replace '(?s)# ={70,}\r?\n# BloodHound Export Block.*?(?=\r?\n# ={70,}|$)', ''
    Set-Content $_.FullName -Value $content -NoNewline
}
```

---

## 📈 Progress Tracking

Use this checklist to track implementation:

### Phase 1: Critical Blockers
- [ ] Dry run completed
- [ ] Fixes applied
- [ ] Verification passed
- [ ] Full audit re-run (A1=0, A2=0)
- [ ] Manual spot checks passed

### Phase 2: High Priority
- [ ] B8 fixes applied (Add-Type guard)
- [ ] B9 fixes applied (public class)
- [ ] B10 fixes applied (SearchBase)
- [ ] Combined scripts tested
- [ ] PowerShell scripts tested

### Phase 3: Quality
- [ ] B2 fixes applied (samAccountName)
- [ ] B4 fixes applied (FILETIME)
- [ ] B7 fixes applied (SearchRoot)

### Phase 4: Export Block
- [ ] Export template created
- [ ] Append script created
- [ ] Export blocks added
- [ ] Unit tests passed
- [ ] BloodHound import tested
- [ ] Full suite test passed

---

## 🆘 Troubleshooting

### Issue: Fix script fails on some files

**Solution**: Check file encoding, ensure UTF-8. Re-run with verbose output.

### Issue: Scripts fail after fixes

**Solution**: Check syntax errors, verify regex patterns didn't break code structure.

### Issue: BloodHound JSON invalid

**Solution**: Validate JSON structure, check ObjectIdentifier format (must be SID or DN).

### Issue: Nodes don't appear in BloodHound

**Solution**: Verify ObjectIdentifier uniqueness, check domain name format.

---

## 📞 Support

For issues during implementation:
1. Review audit report for specific file details
2. Check backup directory for original files
3. Test individual files in isolation
4. Validate JSON output format

---

**Last Updated**: March 13, 2026  
**Version**: 1.0  
**Status**: Ready for implementation
