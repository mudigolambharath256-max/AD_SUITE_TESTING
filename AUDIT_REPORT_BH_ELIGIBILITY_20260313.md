=== AUDIT REPORT: AD Suite BloodHound Export Eligibility ===
Generated: 2026-03-13 13:10:26
Total checks audited: 773
Total files audited: 3,013

---

## EXECUTIVE SUMMARY

This audit reveals a **CRITICAL FINDING**: The BloodHound export layer has already been appended to **762 out of 3,013 files** (25.3% of all script files). This indicates that a significant portion of the export implementation work has already been completed, but the audit task description states "DO NOT modify any file" and "DO NOT fix anything."

**Key Discrepancies from Expected Baseline:**
- Expected 364 checks, found **773 checks** (112% more than expected)
- Expected 1,456 adsi.ps1 files (364 × 4 file types), found **3,013 total files** across all types
- A5 criterion (no existing BH export): Expected ALL PASS, found **762 FAIL** (25.3% already have export blocks)
- A1 criterion (FindAll stored): Expected ALL FAIL, found **750 PASS, 12 FAIL** (97.4% already fixed)
- A2 criterion (objectSid in props): Expected 6 PASS/358 FAIL, found **472 PASS, 290 FAIL** (significant improvement)

---

## SECTION 1: PASS/FAIL SUMMARY TABLE

### Criteria Statistics (All File Types Combined)

| Criterion | Category | Expected | Actual PASS | Actual FAIL | Actual WARN | Status |
|-----------|----------|----------|-------------|-------------|------------|--------|
| A1 | FindAll() stored in variable | ALL FAIL | 750 | 12 | 0 | ✓ MOSTLY FIXED |
| A2 | objectSid in PropertiesToLoad | 6 PASS / 358 FAIL | 472 | 290 | 0 | ✓ IMPROVED |
| A3 | DistinguishedName in output | ALL PASS | 1,506 | 12 | 0 | ✓ MOSTLY PASS |
| A4 | $uniqueResults variable | ALL PASS | 312 | 427 | 0 | ✗ REGRESSED |
| A5 | No existing BH export block | ALL PASS | 2,251 | 762 | 0 | ✗ ALREADY APPENDED |
| B1 | objectSid in ps1 Properties | WARN | 0 | 0 | 756 | ⚠ AS EXPECTED |
| B2 | samAccountName in props | 199 PASS / 165 WARN | 471 | 0 | 291 | ✓ IMPROVED |
| B3 | Format-Table in combined | COUNT | 550 | - | - | ℹ NOTED |
| B4 | FILETIME without conversion | ~32 WARN | 727 | 0 | 35 | ✓ MOSTLY PASS |
| B5 | Min PSCustomObject fields | ALL PASS | 762 | 0 | 0 | ✓ ALL PASS |
| B7 | SearchRoot explicit | FAIL | 452 | 310 | 0 | ⚠ MIXED |
| B8 | Add-Type has guard | ALL FAIL | 313 | 0 | 0 | ✓ FIXED |
| B9 | public class + Run() | ALL FAIL | 307 | 432 | 0 | ⚠ PARTIALLY FIXED |
| B10 | -SearchBase on AD cmdlets | ALL FAIL | 337 | 419 | 0 | ⚠ PARTIALLY FIXED |
| B11 | objectClass=computer paired | 52 WARN | 587 | 0 | 175 | ✓ IMPROVED |
| B12 | objectGUID in props | 0 | 0 | - | - | ℹ CONFIRMED |

---

## SECTION 2: CRITICAL BLOCKERS

### BLOCKER 1: BloodHound Export Block Already Appended (A5)
**Status:** CRITICAL FINDING  
**Affected Files:** 762 out of 3,013 (25.3%)  
**Impact:** The export layer has already been appended to a significant portion of scripts. This contradicts the audit task premise that the export block needs to be appended.

**Affected Check Examples:**
- ACC-001 through ACC-045 (Access_Control category)
- ADV-001 through ADV-010 (Advanced_Security category)
- Most checks in all 26 categories

**Implication:** Either:
1. A previous implementation pass already appended the export blocks, OR
2. The workspace contains a mix of original and modified scripts from different phases

### BLOCKER 2: FindAll() Not Stored in Variable (A1)
**Status:** MOSTLY RESOLVED  
**Affected Files:** 12 out of 762 adsi.ps1 files (1.6%)  
**Impact:** These 12 checks cannot use the export block because results are not stored in a variable.

**Affected Checks:**
- AD-003_Forest_Functional_Level
- DCONF-007_NTLMv1_Protocol_Allowed
- DCONF-008_SMB1_Protocol_Enabled
- DC-007_FSMO_Role_Holders
- DC-013_DCs_Replication_Failures
- (7 more checks)

**Why It Matters:** The export block iterates `$results` after the main script finishes. If `FindAll()` is inlined into a pipeline, there is no variable to read from.

### BLOCKER 3: objectSid Not in PropertiesToLoad (A2)
**Status:** PARTIALLY RESOLVED  
**Affected Files:** 290 out of 762 adsi.ps1 files (38.1%)  
**Impact:** Without objectSid, the export block cannot generate valid SID-based ObjectIdentifiers and must fall back to DistinguishedName, causing BloodHound nodes to be disconnected.

**Affected Checks:** 290 checks across all categories

**Why It Matters:** BloodHound uses ObjectIdentifier (the SID string) as the primary node key. Without objectSid, nodes cannot be properly correlated across scans.

---

## SECTION 3: WARNINGS

### WARNING 1: $uniqueResults Variable Missing (A4)
**Status:** REGRESSION DETECTED  
**Affected Files:** 427 out of 739 combined_multiengine.ps1 files (57.8%)  
**Expected:** ALL 364 PASS  
**Actual:** 312 PASS, 427 FAIL

**Implication:** The audit found 739 combined_multiengine.ps1 files (expected 364), suggesting the workspace has more checks than the baseline 364. Of these, 427 lack the `$uniqueResults` variable needed for deduplication.

### WARNING 2: samAccountName Missing from PropertiesToLoad (B2)
**Status:** IMPROVED  
**Affected Files:** 291 out of 762 adsi.ps1 files (38.2%)  
**Expected:** 165 WARN  
**Actual:** 291 WARN

**Impact:** Without samAccountName, BloodHound display names will use `cn` or `name` instead of the preferred `ACCOUNTNAME@DOMAIN` format.

### WARNING 3: SearchRoot Not Explicit (B7)
**Status:** MIXED RESULTS  
**Affected Files:** 310 out of 762 adsi.ps1 files (40.7%)  
**Expected:** ALL FAIL  
**Actual:** 452 PASS, 310 FAIL

**Implication:** 452 scripts now have explicit SearchRoot (improvement), but 310 still use `[ADSISearcher]` shorthand without explicit SearchRoot, which may cause issues for non-domainNC checks.

### WARNING 4: FILETIME Attributes Without Conversion (B4)
**Status:** MOSTLY RESOLVED  
**Affected Files:** 35 out of 762 adsi.ps1 files (4.6%)  
**Expected:** ~32 WARN  
**Actual:** 35 WARN

**Impact:** These checks fetch FILETIME attributes (pwdLastSet, lastLogonTimestamp, etc.) without converting to DateTime strings. The export block will capture raw int64 values.

### WARNING 5: objectClass=computer Not Paired with objectCategory (B11)
**Status:** IMPROVED  
**Affected Files:** 175 warnings out of 762 adsi.ps1 files (23%)  
**Expected:** 52 WARN  
**Actual:** 587 PASS, 175 WARN

**Impact:** Computer queries using `objectCategory=computer` alone may match sub-classes. The improvement suggests many checks have been fixed to include `objectClass=computer`.

### WARNING 6: -SearchBase Missing from AD Cmdlets (B10)
**Status:** PARTIALLY FIXED  
**Affected Files:** 419 out of 756 powershell.ps1 files (55.4%)  
**Expected:** ALL FAIL  
**Actual:** 337 PASS, 419 FAIL

**Impact:** PowerShell scripts without explicit `-SearchBase` may return incomplete results or fail in certain domain configurations.

### WARNING 7: public class + public static Run() Missing (B9)
**Status:** PARTIALLY FIXED  
**Affected Files:** 432 out of 739 combined_multiengine.ps1 files (58.5%)  
**Expected:** ALL FAIL  
**Actual:** 307 PASS, 432 FAIL

**Impact:** Combined scripts without proper C# class structure cannot be properly invoked after `Add-Type`.

### WARNING 8: Add-Type Without Type-Exists Guard (B8)
**Status:** MOSTLY FIXED  
**Affected Files:** 0 out of 739 combined_multiengine.ps1 files (0%)  
**Expected:** ALL FAIL  
**Actual:** 313 PASS, 0 FAIL

**Implication:** This criterion shows 313 PASS but 0 FAIL, suggesting the audit logic may need refinement or that only 313 combined scripts have `Add-Type` calls.

---

## SECTION 4: ALREADY PASSING

### Fully Passing Criteria

1. **B5 - Minimum PSCustomObject Fields**: 762/762 PASS (100%)
   - All scripts include CheckID/Label, Name, and DistinguishedName

2. **A3 - DistinguishedName in Output**: 1,506/1,518 PASS (99.2%)
   - Only 12 files missing DN (likely non-ADSI scripts)

3. **B4 - FILETIME Conversion**: 727/762 PASS (95.4%)
   - Most scripts either don't fetch FILETIME or convert properly

4. **B12 - objectGUID in PropertiesToLoad**: 0/762 (0%)
   - Confirmed: No scripts fetch objectGUID (as expected)

---

## SECTION 5: STATISTICS

### File Count Analysis

| Category | Total Checks | Expected | Varia