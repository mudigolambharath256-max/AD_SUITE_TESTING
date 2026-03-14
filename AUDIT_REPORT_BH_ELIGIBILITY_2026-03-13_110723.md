================================================================================
AUDIT REPORT: AD Suite BloodHound Export Eligibility
================================================================================
Generated: 2026-03-13 11:07:28
Total checks audited: 774
Total files audited: 2257

================================================================================
SECTION 1: CRITICAL BLOCKERS (MUST FIX BEFORE EXPORT)
================================================================================

Total Critical Blockers: 18

A1 - FindAll() stored in variable:
  PASS: 750
  FAIL: 12
  
A2 - objectSid in PropertiesToLoad:
  PASS: 756
  FAIL: 6

Critical Blocker Details:
  - AD-003/adsi.ps1: A1 FAIL - FindAll() not stored in variable
  - DCONF-007/adsi.ps1: A1 FAIL - FindAll() not stored in variable
  - DCONF-008/adsi.ps1: A1 FAIL - FindAll() not stored in variable
  - DC-007/adsi.ps1: A1 FAIL - FindAll() not stored in variable
  - DC-013/adsi.ps1: A1 FAIL - FindAll() not stored in variable
  - DC-013/adsi.ps1: A2 FAIL - objectSid missing from PropertiesToLoad
  - DC-019/adsi.ps1: A1 FAIL - FindAll() not stored in variable
  - DC-019/adsi.ps1: A2 FAIL - objectSid missing from PropertiesToLoad
  - DC-025/adsi.ps1: A1 FAIL - FindAll() not stored in variable
  - DC-025/adsi.ps1: A2 FAIL - objectSid missing from PropertiesToLoad
  - DC-027/adsi.ps1: A1 FAIL - FindAll() not stored in variable
  - DC-027/adsi.ps1: A2 FAIL - objectSid missing from PropertiesToLoad
  - DC-028/adsi.ps1: A1 FAIL - FindAll() not stored in variable
  - DC-028/adsi.ps1: A2 FAIL - objectSid missing from PropertiesToLoad
  - GPO-051/adsi.ps1: A1 FAIL - FindAll() not stored in variable
  - GPO-051/adsi.ps1: A2 FAIL - objectSid missing from PropertiesToLoad
  - SECACCT-002/adsi.ps1: A1 FAIL - FindAll() not stored in variable
  - TRST-031/adsi.ps1: A1 FAIL - FindAll() not stored in variable


================================================================================
SECTION 2: STATISTICS
================================================================================

CRITICAL CRITERIA (Group A):
  A1 (FindAll stored):         PASS=750   FAIL=12
  A2 (objectSid in props):     PASS=756   FAIL=6
  A3 (DN in output):           PASS=754   FAIL=8
  A4 (uniqueResults exists):   PASS=312   FAIL=427
  A5 (no existing BH export):  PASS=762   FAIL=0

WARNING CRITERIA (Group B):
  B1 (SID in ps1 props):       PASS=61   WARN=695
  B2 (samAccountName):         PASS=0   WARN=762
  B3 (Format-Table):           COUNT=550
  B4 (FILETIME raw):           PASS=727   WARN=35
  B5 (min PSCustomObject):     PASS=338   WARN=424
  B7 (SearchRoot explicit):    PASS=452   FAIL=310
  B8 (Add-Type guard):         PASS=0   FAIL=739
  B9 (public class/Run):       PASS=6   FAIL=733
  B10 (-SearchBase):           PASS=435   FAIL=321
  B11 (objectClass=computer):  PASS=0   WARN=175
  B12 (objectGUID):            COUNT=0

================================================================================
SECTION 3: PRIORITY FIX LIST
================================================================================

PRIORITY 1 — CRITICAL (blocks export block from working):
  FIX-A1: Store FindAll() in $results variable in 12 adsi.ps1 files
  FIX-A2: Add 'objectSid' to PropertiesToLoad in 6 adsi.ps1 files

PRIORITY 2 — HIGH (affects correctness):
  FIX-B8: Add type-exists guard around Add-Type in 739 combined scripts
  FIX-B9: Make C# class public, rename Run() in 733 combined scripts
  FIX-B10: Add -SearchBase to Get-AD* calls in 321 powershell.ps1 files

PRIORITY 3 — MEDIUM (affects quality):
  FIX-B2: Add 'samAccountName' to PropertiesToLoad in 762 adsi.ps1 files
  FIX-B4: Convert FILETIME attributes in 35 adsi.ps1 files
  FIX-B7: Fix SearchRoot for non-domainNC checks in 310 adsi.ps1 files

PRIORITY 4 — LOW (known bugs, separate pass):
  FIX-B3: Replace Format-Table with Format-List in 550 combined scripts

================================================================================
CONCLUSION
================================================================================

Ready for BloodHound Export Append: NO

Critical blockers must be resolved before appending BloodHound export block.
