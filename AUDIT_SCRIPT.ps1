# ============================================================================
# BloodHound Export Eligibility Audit Script
# AD Security Suite — Read-Only Diagnostic Pass
# ============================================================================

$auditStart = Get-Date
$auditResults = @()
$categoryStats = @{}
$criteriaStats = @{
    'A1_FindAll_stored' = @{ pass = 0; fail = 0; warn = 0 }
    'A2_objectSid_in_props' = @{ pass = 0; fail = 0; warn = 0 }
    'A3_DN_in_output' = @{ pass = 0; fail = 0; warn = 0 }
    'A4_uniqueResults_exists' = @{ pass = 0; fail = 0; warn = 0 }
    'A5_no_existing_BH_export' = @{ pass = 0; fail = 0; warn = 0 }
    'B1_SID_in_ps1_props' = @{ pass = 0; fail = 0; warn = 0 }
    'B2_samAccountName' = @{ pass = 0; fail = 0; warn = 0 }
    'B3_FormatTable' = @{ count = 0 }
    'B4_FILETIME_raw' = @{ pass = 0; fail = 0; warn = 0 }
    'B5_min_PSCustomObject' = @{ pass = 0; fail = 0; warn = 0 }
    'B7_SearchRoot_explicit' = @{ pass = 0; fail = 0; warn = 0 }
    'B8_AddType_guard' = @{ pass = 0; fail = 0; warn = 0 }
    'B9_public_class_Run' = @{ pass = 0; fail = 0; warn = 0 }
    'B10_SearchBase' = @{ pass = 0; fail = 0; warn = 0 }
    'B11_objectClass_computer' = @{ pass = 0; fail = 0; warn = 0; exempt = 0 }
    'B12_objectGUID' = @{ count = 0 }
}

# Get all category directories
$categories = Get-ChildItem -Directory -Path . | Where-Object { 
    $_.Name -notmatch '^(backups|\.vscode|ad-suite-web|node_modules)' 
} | Sort-Object Name

$totalChecks = 0
$totalFiles = 0

Write-Host "Starting BloodHound Export Eligibility Audit..." -ForegroundColor Cyan
Write-Host "Categories to audit: $($categories.Count)" -ForegroundColor Gray

foreach ($category in $categories) {
    $categoryName = $category.Name
    $checkFolders = Get-ChildItem -Directory -Path $category.FullName
    
    Write-Host "`n[$categoryName] Found $($checkFolders.Count) checks" -ForegroundColor Yellow
    
    foreach ($checkFolder in $checkFolders) {
        $checkName = $checkFolder.Name
        $totalChecks++
        
        # Extract check ID from folder name (e.g., "ACC-001" from "ACC-001_Privileged_Users_adminCount1")
        if ($checkName -match '^([A-Z]+-\d+)') {
            $checkID = $matches[1]
        } else {
            $checkID = $checkName
        }
        
        $checkResult = @{
            CheckID = $checkID
            CheckName = $checkName
            Category = $categoryName
            Files = @{}
            Summary = @{}
        }
        
        # Audit each file type
        $fileTypes = @('adsi.ps1', 'powershell.ps1', 'combined_multiengine.ps1', 'csharp.cs')
        
        foreach ($fileType in $fileTypes) {
            $filePath = Join-Path $checkFolder.FullName $fileType
            
            if (Test-Path $filePath) {
                $totalFiles++
                $fileContent = Get-Content -Path $filePath -Raw
                $fileResult = @{
                    Exists = $true
                    Criteria = @{}
                }
                
                # ===== ADSI.PS1 AUDITS =====
                if ($fileType -eq 'adsi.ps1') {
                    # A1: FindAll() stored in variable
                    if ($fileContent -match '\$results\s*=\s*\$searcher\.FindAll\(\)') {
                        $fileResult.Criteria['A1'] = 'PASS'
                        $criteriaStats['A1_FindAll_stored'].pass++
                    } else {
                        $fileResult.Criteria['A1'] = 'FAIL'
                        $criteriaStats['A1_FindAll_stored'].fail++
                    }
                    
                    # A2: objectSid in PropertiesToLoad
                    if ($fileContent -match "PropertiesToLoad.*'objectSid'|'objectSid'.*PropertiesToLoad") {
                        $fileResult.Criteria['A2'] = 'PASS'
                        $criteriaStats['A2_objectSid_in_props'].pass++
                    } else {
                        $fileResult.Criteria['A2'] = 'FAIL'
                        $criteriaStats['A2_objectSid_in_props'].fail++
                    }
                    
                    # A3: DistinguishedName in PSCustomObject
                    if ($fileContent -match 'DistinguishedName\s*=') {
                        $fileResult.Criteria['A3'] = 'PASS'
                        $criteriaStats['A3_DN_in_output'].pass++
                    } else {
                        $fileResult.Criteria['A3'] = 'FAIL'
                        $criteriaStats['A3_DN_in_output'].fail++
                    }
                    
                    # A5: No existing BloodHound export block
                    if ($fileContent -notmatch 'ConvertTo-Json|bloodhound|BloodHound|ADSUITE_SESSION_ID|bhDir') {
                        $fileResult.Criteria['A5'] = 'PASS'
                        $criteriaStats['A5_no_existing_BH_export'].pass++
                    } else {
                        $fileResult.Criteria['A5'] = 'FAIL'
                        $criteriaStats['A5_no_existing_BH_export'].fail++
                    }
                    
                    # B2: samAccountName in PropertiesToLoad
                    if ($fileContent -match "PropertiesToLoad.*'samAccountName'|'samAccountName'.*PropertiesToLoad") {
                        $fileResult.Criteria['B2'] = 'PASS'
                        $criteriaStats['B2_samAccountName'].pass++
                    } else {
                        $fileResult.Criteria['B2'] = 'WARN'
                        $criteriaStats['B2_samAccountName'].warn++
                    }
                    
                    # B4: FILETIME without conversion
                    $filetimeAttrs = @('pwdLastSet', 'lastLogonTimestamp', 'accountExpires', 'badPasswordTime', 'lockoutTime')
                    $hasFiletime = $false
                    $hasConversion = $false
                    foreach ($attr in $filetimeAttrs) {
                        if ($fileContent -match $attr) {
                            $hasFiletime = $true
                            if ($fileContent -match '\[DateTime\]::FromFileTime') {
                                $hasConversion = $true
                            }
                            break
                        }
                    }
                    if ($hasFiletime -and -not $hasConversion) {
                        $fileResult.Criteria['B4'] = 'WARN'
                        $criteriaStats['B4_FILETIME_raw'].warn++
                    } else {
                        $fileResult.Criteria['B4'] = 'PASS'
                        $criteriaStats['B4_FILETIME_raw'].pass++
                    }
                    
                    # B5: Minimum PSCustomObject fields
                    $hasLabel = $fileContent -match 'CheckID|Label'
                    $hasName = $fileContent -match 'Name\s*='
                    $hasDN = $fileContent -match 'DistinguishedName\s*='
                    if ($hasLabel -and $hasName -and $hasDN) {
                        $fileResult.Criteria['B5'] = 'PASS'
                        $criteriaStats['B5_min_PSCustomObject'].pass++
                    } else {
                        $fileResult.Criteria['B5'] = 'WARN'
                        $criteriaStats['B5_min_PSCustomObject'].warn++
                    }
                    
                    # B7: SearchRoot explicit for non-domainNC
                    if ($fileContent -match 'SearchRoot\s*=|SearchRoot\s*\|') {
                        $fileResult.Criteria['B7'] = 'PASS'
                        $criteriaStats['B7_SearchRoot_explicit'].pass++
                    } else {
                        $fileResult.Criteria['B7'] = 'FAIL'
                        $criteriaStats['B7_SearchRoot_explicit'].fail++
                    }
                    
                    # B11: objectClass=computer paired with objectCategory
                    if ($fileContent -match 'objectCategory=computer') {
                        if ($fileContent -match 'objectClass=computer') {
                            $fileResult.Criteria['B11'] = 'PASS'
                            $criteriaStats['B11_objectClass_computer'].pass++
                        } else {
                            $fileResult.Criteria['B11'] = 'WARN'
                            $criteriaStats['B11_objectClass_computer'].warn++
                        }
                    } else {
                        $fileResult.Criteria['B11'] = 'PASS'
                        $criteriaStats['B11_objectClass_computer'].pass++
                    }
                    
                    # B12: objectGUID in PropertiesToLoad
                    if ($fileContent -match "'objectGUID'") {
                        $criteriaStats['B12_objectGUID'].count++
                    }
                }
                
                # ===== POWERSHELL.PS1 AUDITS =====
                elseif ($fileType -eq 'powershell.ps1') {
                    # A3: DistinguishedName in output
                    if ($fileContent -match 'DistinguishedName') {
                        $fileResult.Criteria['A3'] = 'PASS'
                        $criteriaStats['A3_DN_in_output'].pass++
                    } else {
                        $fileResult.Criteria['A3'] = 'FAIL'
                        $criteriaStats['A3_DN_in_output'].fail++
                    }
                    
                    # A5: No existing BloodHound export block
                    if ($fileContent -notmatch 'ConvertTo-Json|bloodhound|BloodHound|ADSUITE_SESSION_ID|bhDir') {
                        $fileResult.Criteria['A5'] = 'PASS'
                        $criteriaStats['A5_no_existing_BH_export'].pass++
                    } else {
                        $fileResult.Criteria['A5'] = 'FAIL'
                        $criteriaStats['A5_no_existing_BH_export'].fail++
                    }
                    
                    # B1: objectSid in Properties list
                    if ($fileContent -match '-Properties.*objectSid|objectSid.*-Properties') {
                        $fileResult.Criteria['B1'] = 'PASS'
                        $criteriaStats['B1_SID_in_ps1_props'].pass++
                    } else {
                        $fileResult.Criteria['B1'] = 'WARN'
                        $criteriaStats['B1_SID_in_ps1_props'].warn++
                    }
                    
                    # B10: -SearchBase on every AD cmdlet
                    $adCmdlets = @('Get-ADObject', 'Get-ADUser', 'Get-ADComputer', 'Get-ADGroup')
                    $hasAllSearchBase = $true
                    foreach ($cmdlet in $adCmdlets) {
                        if ($fileContent -match $cmdlet) {
                            if ($fileContent -notmatch "$cmdlet.*-SearchBase|-SearchBase.*$cmdlet") {
                                $hasAllSearchBase = $false
                                break
                            }
                        }
                    }
                    if ($hasAllSearchBase) {
                        $fileResult.Criteria['B10'] = 'PASS'
                        $criteriaStats['B10_SearchBase'].pass++
                    } else {
                        $fileResult.Criteria['B10'] = 'FAIL'
                        $criteriaStats['B10_SearchBase'].fail++
                    }
                }
                
                # ===== COMBINED_MULTIENGINE.PS1 AUDITS =====
                elseif ($fileType -eq 'combined_multiengine.ps1') {
                    # A4: $uniqueResults variable present
                    if ($fileContent -match '\$uniqueResults') {
                        $fileResult.Criteria['A4'] = 'PASS'
                        $criteriaStats['A4_uniqueResults_exists'].pass++
                    } else {
                        $fileResult.Criteria['A4'] = 'FAIL'
                        $criteriaStats['A4_uniqueResults_exists'].fail++
                    }
                    
                    # A5: No existing BloodHound export block
                    if ($fileContent -notmatch 'ConvertTo-Json|bloodhound|BloodHound|ADSUITE_SESSION_ID|bhDir') {
                        $fileResult.Criteria['A5'] = 'PASS'
                        $criteriaStats['A5_no_existing_BH_export'].pass++
                    } else {
                        $fileResult.Criteria['A5'] = 'FAIL'
                        $criteriaStats['A5_no_existing_BH_export'].fail++
                    }
                    
                    # B3: Format-Table present
                    if ($fileContent -match 'Format-Table') {
                        $criteriaStats['B3_FormatTable'].count++
                    }
                    
                    # B8: Add-Type has type-exists guard
                    if ($fileContent -match 'Add-Type') {
                        if ($fileContent -match '\[System\.Management\.Automation\.PSTypeName\]') {
                            $fileResult.Criteria['B8'] = 'PASS'
                            $criteriaStats['B8_AddType_guard'].pass++
                        } else {
                            $fileResult.Criteria['B8'] = 'FAIL'
                            $criteriaStats['B8_AddType_guard'].fail++
                        }
                    }
                    
                    # B9: public class + public static Run()
                    if ($fileContent -match 'public\s+class' -and $fileContent -match 'public\s+static\s+void\s+Run') {
                        $fileResult.Criteria['B9'] = 'PASS'
                        $criteriaStats['B9_public_class_Run'].pass++
                    } else {
                        $fileResult.Criteria['B9'] = 'FAIL'
                        $criteriaStats['B9_public_class_Run'].fail++
                    }
                }
                
                # ===== CSHARP.CS AUDITS =====
                elseif ($fileType -eq 'csharp.cs') {
                    # A5: No existing BloodHound export block
                    if ($fileContent -notmatch 'ConvertTo-Json|bloodhound|BloodHound|ADSUITE_SESSION_ID|bhDir') {
                        $fileResult.Criteria['A5'] = 'PASS'
                        $criteriaStats['A5_no_existing_BH_export'].pass++
                    } else {
                        $fileResult.Criteria['A5'] = 'FAIL'
                        $criteriaStats['A5_no_existing_BH_export'].fail++
                    }
                }
                
                $checkResult.Files[$fileType] = $fileResult
            }
        }
        
        $auditResults += $checkResult
    }
}

# Generate report
$reportPath = "AUDIT_REPORT_BH_ELIGIBILITY_$(Get-Date -Format 'yyyyMMdd_HHmmss').md"
$summaryPath = "AUDIT_SUMMARY_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"

Write-Host "`n`nAudit Complete!" -ForegroundColor Green
Write-Host "Total checks audited: $totalChecks" -ForegroundColor Gray
Write-Host "Total files audited: $totalFiles" -ForegroundColor Gray
Write-Host "Report will be saved to: $reportPath" -ForegroundColor Cyan

# Output summary stats
Write-Host "`n=== CRITERIA STATISTICS ===" -ForegroundColor Cyan
$criteriaStats | ConvertTo-Json | Write-Host
