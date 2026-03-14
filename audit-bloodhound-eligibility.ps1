# ============================================================================
# BloodHound Export Eligibility Audit Script
# READ-ONLY ANALYSIS - NO MODIFICATIONS
# ============================================================================

param(
    [string]$OutputPath = "AUDIT_REPORT_BH_ELIGIBILITY_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').md",
    [string]$JsonPath = "AUDIT_SUMMARY_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').json"
)

$ErrorActionPreference = 'Continue'

# Initialize counters
$stats = @{
    totalChecks = 0
    totalFiles = 0
    A1_FindAll_stored = @{ pass = 0; fail = 0; warn = 0 }
    A2_objectSid_in_props = @{ pass = 0; fail = 0; warn = 0 }
    A3_DN_in_output = @{ pass = 0; fail = 0; warn = 0 }
    A4_uniqueResults_exists = @{ pass = 0; fail = 0; warn = 0 }
    A5_no_existing_BH_export = @{ pass = 0; fail = 0; warn = 0 }
    B1_SID_in_ps1_props = @{ pass = 0; fail = 0; warn = 0 }
    B2_samAccountName = @{ pass = 0; fail = 0; warn = 0 }
    B3_FormatTable = @{ count = 0 }
    B4_FILETIME_raw = @{ pass = 0; fail = 0; warn = 0 }
    B5_min_PSCustomObject = @{ pass = 0; fail = 0; warn = 0 }
    B7_SearchRoot_explicit = @{ pass = 0; fail = 0; warn = 0 }
    B8_AddType_guard = @{ pass = 0; fail = 0; warn = 0 }
    B9_public_class_Run = @{ pass = 0; fail = 0; warn = 0 }
    B10_SearchBase = @{ pass = 0; fail = 0; warn = 0 }
    B11_objectClass_computer = @{ pass = 0; fail = 0; warn = 0; exempt = 0 }
    B12_objectGUID = @{ count = 0 }
}

$findings = @()
$criticalBlockers = @()

Write-Host "=== BloodHound Export Eligibility Audit ===" -ForegroundColor Cyan
Write-Host "Starting audit at $(Get-Date)" -ForegroundColor Gray
Write-Host ""

# Get all category directories
$categories = Get-ChildItem -Directory | Where-Object { 
    $_.Name -notmatch '^(ad-suite-web|\.vscode)$' 
}

Write-Host "Found $($categories.Count) categories" -ForegroundColor Green

foreach ($category in $categories) {
    Write-Host "Processing category: $($category.Name)" -ForegroundColor Yellow
    
    $checks = Get-ChildItem -Path $category.FullName -Directory
    
    foreach ($check in $checks) {
        $stats.totalChecks++
        $checkId = $check.Name -replace '_.*$', ''
        
        # Check for adsi.ps1
        $adsiPath = Join-Path $check.FullName "adsi.ps1"
        if (Test-Path $adsiPath) {
            $stats.totalFiles++
            $content = Get-Content $adsiPath -Raw -ErrorAction SilentlyContinue
            
            if ($content) {
                # A1: FindAll() stored in variable
                # Check if FindAll() is stored in ANY variable (not directly piped or used in foreach)
                # Note: FindOne() doesn't need to be stored, only FindAll()
                $hasFindAll = $content -match '\.FindAll\(\)'
                
                if ($hasFindAll) {
                    $hasStoredFindAll = $content -match '\$\w+\s*=\s*\$\w+\.FindAll\(\)'
                    $hasDirectPipe = $content -match '\$\w+\.FindAll\(\)\s*\|'
                    $hasDirectForeach = $content -match 'foreach\s*\(\s*\$\w+\s+in\s+\$\w+\.FindAll\(\)'
                    
                    if ($hasStoredFindAll -and -not $hasDirectPipe -and -not $hasDirectForeach) {
                        $stats.A1_FindAll_stored.pass++
                    } else {
                        $stats.A1_FindAll_stored.fail++
                        $criticalBlockers += "$checkId/adsi.ps1: A1 FAIL - FindAll() not stored in variable"
                    }
                } else {
                    # No FindAll() in this file (might use FindOne() or other methods)
                    $stats.A1_FindAll_stored.pass++
                }
                
                # A2: objectSid in PropertiesToLoad
                # Use (?s) flag to make . match newlines, or just check if objectSid exists anywhere
                if ($content -match "'objectSid'|`"objectSid`"") {
                    $stats.A2_objectSid_in_props.pass++
                } else {
                    $stats.A2_objectSid_in_props.fail++
                    $criticalBlockers += "$checkId/adsi.ps1: A2 FAIL - objectSid missing from PropertiesToLoad"
                }
                
                # A3: DistinguishedName in output
                if ($content -match 'DistinguishedName\s*=') {
                    $stats.A3_DN_in_output.pass++
                } else {
                    $stats.A3_DN_in_output.fail++
                }
                
                # A5: No existing BH export
                if ($content -match 'ConvertTo-Json|bloodhound|BloodHound|ADSUITE_SESSION_ID|bhDir') {
                    $stats.A5_no_existing_BH_export.fail++
                } else {
                    $stats.A5_no_existing_BH_export.pass++
                }
                
                # B2: samAccountName in PropertiesToLoad
                if ($content -match "'samAccountName'|`"samAccountName`"") {
                    $stats.B2_samAccountName.pass++
                } else {
                    $stats.B2_samAccountName.warn++
                }
                
                # B4: FILETIME without conversion
                $filetimeAttrs = @('pwdLastSet', 'lastLogonTimestamp', 'accountExpires', 'badPasswordTime', 'lockoutTime')
                $hasFiletime = $false
                $hasConversion = $content -match '\[DateTime\]::FromFileTime'
                
                foreach ($attr in $filetimeAttrs) {
                    if ($content -match $attr) {
                        $hasFiletime = $true
                        break
                    }
                }
                
                if ($hasFiletime -and -not $hasConversion) {
                    $stats.B4_FILETIME_raw.warn++
                } else {
                    $stats.B4_FILETIME_raw.pass++
                }
                
                # B5: Minimum PSCustomObject fields
                $hasLabel = $content -match 'Label\s*='
                $hasName = $content -match 'Name\s*='
                $hasDN = $content -match 'DistinguishedName\s*='
                
                if ($hasLabel -and $hasName -and $hasDN) {
                    $stats.B5_min_PSCustomObject.pass++
                } else {
                    $stats.B5_min_PSCustomObject.warn++
                }
                
                # B7: SearchRoot explicit
                if ($content -match '\[ADSISearcher\]') {
                    $stats.B7_SearchRoot_explicit.fail++
                } else {
                    $stats.B7_SearchRoot_explicit.pass++
                }
                
                # B11: objectClass=computer with objectCategory=computer
                if ($content -match 'objectCategory=computer') {
                    if ($content -match 'objectClass=computer') {
                        $stats.B11_objectClass_computer.pass++
                    } else {
                        $stats.B11_objectClass_computer.warn++
                    }
                }
                
                # B12: objectGUID
                if ($content -match "PropertiesToLoad.*'objectGUID'|PropertiesToLoad.*`"objectGUID`"") {
                    $stats.B12_objectGUID.count++
                }
            }
        }
        
        # Check for powershell.ps1
        $ps1Path = Join-Path $check.FullName "powershell.ps1"
        if (Test-Path $ps1Path) {
            $stats.totalFiles++
            $content = Get-Content $ps1Path -Raw -ErrorAction SilentlyContinue
            
            if ($content) {
                # A3: DistinguishedName in output
                if ($content -match 'DistinguishedName') {
                    # Already counted in adsi check
                }
                
                # B1: objectSid in Properties (simplified check)
                if ($content -match "'objectSid'|`"objectSid`"") {
                    $stats.B1_SID_in_ps1_props.pass++
                } else {
                    $stats.B1_SID_in_ps1_props.warn++
                }
                
                # B10: -SearchBase present
                if ($content -match 'Get-AD(Object|User|Computer|Group)' -and $content -notmatch '-SearchBase') {
                    $stats.B10_SearchBase.fail++
                } else {
                    $stats.B10_SearchBase.pass++
                }
            }
        }
        
        # Check for combined_multiengine.ps1
        $combinedPath = Join-Path $check.FullName "combined_multiengine.ps1"
        if (Test-Path $combinedPath) {
            $stats.totalFiles++
            $content = Get-Content $combinedPath -Raw -ErrorAction SilentlyContinue
            
            if ($content) {
                # A4: $uniqueResults variable
                if ($content -match '\$uniqueResults') {
                    $stats.A4_uniqueResults_exists.pass++
                } else {
                    $stats.A4_uniqueResults_exists.fail++
                }
                
                # B3: Format-Table
                if ($content -match 'Format-Table') {
                    $stats.B3_FormatTable.count++
                }
                
                # B8: Add-Type guard
                if ($content -match 'PSTypeName.*Type\)') {
                    $stats.B8_AddType_guard.pass++
                } else {
                    $stats.B8_AddType_guard.fail++
                }
                
                # B9: public class + public static Run()
                if ($content -match 'public class' -and $content -match 'public static.*Run') {
                    $stats.B9_public_class_Run.pass++
                } else {
                    $stats.B9_public_class_Run.fail++
                }
            }
        }
        
        if ($stats.totalChecks % 50 -eq 0) {
            Write-Host "  Processed $($stats.totalChecks) checks..." -ForegroundColor Gray
        }
    }
}

Write-Host ""
Write-Host "=== Audit Complete ===" -ForegroundColor Green
Write-Host "Total Checks: $($stats.totalChecks)"
Write-Host "Total Files: $($stats.totalFiles)"
Write-Host "Critical Blockers: $($criticalBlockers.Count)"
Write-Host ""

# Generate report
$report = @"
================================================================================
AUDIT REPORT: AD Suite BloodHound Export Eligibility
================================================================================
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Total checks audited: $($stats.totalChecks)
Total files audited: $($stats.totalFiles)

================================================================================
SECTION 1: CRITICAL BLOCKERS (MUST FIX BEFORE EXPORT)
================================================================================

Total Critical Blockers: $($criticalBlockers.Count)

A1 - FindAll() stored in variable:
  PASS: $($stats.A1_FindAll_stored.pass)
  FAIL: $($stats.A1_FindAll_stored.fail)
  
A2 - objectSid in PropertiesToLoad:
  PASS: $($stats.A2_objectSid_in_props.pass)
  FAIL: $($stats.A2_objectSid_in_props.fail)

Critical Blocker Details:
$($criticalBlockers | ForEach-Object { "  - $_" } | Out-String)

================================================================================
SECTION 2: STATISTICS
================================================================================

CRITICAL CRITERIA (Group A):
  A1 (FindAll stored):         PASS=$($stats.A1_FindAll_stored.pass)   FAIL=$($stats.A1_FindAll_stored.fail)
  A2 (objectSid in props):     PASS=$($stats.A2_objectSid_in_props.pass)   FAIL=$($stats.A2_objectSid_in_props.fail)
  A3 (DN in output):           PASS=$($stats.A3_DN_in_output.pass)   FAIL=$($stats.A3_DN_in_output.fail)
  A4 (uniqueResults exists):   PASS=$($stats.A4_uniqueResults_exists.pass)   FAIL=$($stats.A4_uniqueResults_exists.fail)
  A5 (no existing BH export):  PASS=$($stats.A5_no_existing_BH_export.pass)   FAIL=$($stats.A5_no_existing_BH_export.fail)

WARNING CRITERIA (Group B):
  B1 (SID in ps1 props):       PASS=$($stats.B1_SID_in_ps1_props.pass)   WARN=$($stats.B1_SID_in_ps1_props.warn)
  B2 (samAccountName):         PASS=$($stats.B2_samAccountName.pass)   WARN=$($stats.B2_samAccountName.warn)
  B3 (Format-Table):           COUNT=$($stats.B3_FormatTable.count)
  B4 (FILETIME raw):           PASS=$($stats.B4_FILETIME_raw.pass)   WARN=$($stats.B4_FILETIME_raw.warn)
  B5 (min PSCustomObject):     PASS=$($stats.B5_min_PSCustomObject.pass)   WARN=$($stats.B5_min_PSCustomObject.warn)
  B7 (SearchRoot explicit):    PASS=$($stats.B7_SearchRoot_explicit.pass)   FAIL=$($stats.B7_SearchRoot_explicit.fail)
  B8 (Add-Type guard):         PASS=$($stats.B8_AddType_guard.pass)   FAIL=$($stats.B8_AddType_guard.fail)
  B9 (public class/Run):       PASS=$($stats.B9_public_class_Run.pass)   FAIL=$($stats.B9_public_class_Run.fail)
  B10 (-SearchBase):           PASS=$($stats.B10_SearchBase.pass)   FAIL=$($stats.B10_SearchBase.fail)
  B11 (objectClass=computer):  PASS=$($stats.B11_objectClass_computer.pass)   WARN=$($stats.B11_objectClass_computer.warn)
  B12 (objectGUID):            COUNT=$($stats.B12_objectGUID.count)

================================================================================
SECTION 3: PRIORITY FIX LIST
================================================================================

PRIORITY 1 — CRITICAL (blocks export block from working):
  FIX-A1: Store FindAll() in `$results variable in $($stats.A1_FindAll_stored.fail) adsi.ps1 files
  FIX-A2: Add 'objectSid' to PropertiesToLoad in $($stats.A2_objectSid_in_props.fail) adsi.ps1 files

PRIORITY 2 — HIGH (affects correctness):
  FIX-B8: Add type-exists guard around Add-Type in $($stats.B8_AddType_guard.fail) combined scripts
  FIX-B9: Make C# class public, rename Run() in $($stats.B9_public_class_Run.fail) combined scripts
  FIX-B10: Add -SearchBase to Get-AD* calls in $($stats.B10_SearchBase.fail) powershell.ps1 files

PRIORITY 3 — MEDIUM (affects quality):
  FIX-B2: Add 'samAccountName' to PropertiesToLoad in $($stats.B2_samAccountName.warn) adsi.ps1 files
  FIX-B4: Convert FILETIME attributes in $($stats.B4_FILETIME_raw.warn) adsi.ps1 files
  FIX-B7: Fix SearchRoot for non-domainNC checks in $($stats.B7_SearchRoot_explicit.fail) adsi.ps1 files

PRIORITY 4 — LOW (known bugs, separate pass):
  FIX-B3: Replace Format-Table with Format-List in $($stats.B3_FormatTable.count) combined scripts

================================================================================
CONCLUSION
================================================================================

Ready for BloodHound Export Append: $(if ($stats.A1_FindAll_stored.fail -eq 0 -and $stats.A2_objectSid_in_props.fail -eq 0) { 'YES' } else { 'NO' })

Critical blockers must be resolved before appending BloodHound export block.
"@

# Write report
$report | Out-File -FilePath $OutputPath -Encoding UTF8
Write-Host "Report written to: $OutputPath" -ForegroundColor Green

# Write JSON summary
$jsonSummary = @{
    auditDate = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
    totalChecks = $stats.totalChecks
    totalFiles = $stats.totalFiles
    criteria = $stats
    readyForExportAppend = ($stats.A1_FindAll_stored.fail -eq 0 -and $stats.A2_objectSid_in_props.fail -eq 0)
    criticalBlockerCount = $criticalBlockers.Count
    criticalBlockers = @('A1_FindAll_stored', 'A2_objectSid_in_props')
}

$jsonSummary | ConvertTo-Json -Depth 10 | Out-File -FilePath $JsonPath -Encoding UTF8
Write-Host "JSON summary written to: $JsonPath" -ForegroundColor Green
