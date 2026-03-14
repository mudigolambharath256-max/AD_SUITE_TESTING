# ============================================================================
# Fix Remaining A1 and A2 Issues - Version 2
# ============================================================================
# Fixes the last files with A1/A2 issues based on audit report
# ============================================================================

param([switch]$DryRun)

$ErrorActionPreference = 'Stop'

Write-Host "=== Fixing Remaining A1/A2 Issues (v2) ===" -ForegroundColor Cyan
Write-Host "Mode: $(if ($DryRun) { 'DRY RUN' } else { 'LIVE' })`n" -ForegroundColor $(if ($DryRun) { 'Yellow' } else { 'Red' })

$backupDir = "backups_final_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
if (-not $DryRun) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    Write-Host "Backup directory: $backupDir`n" -ForegroundColor Green
}

# Files from audit report with A1 and/or A2 issues
$filesToFix = @(
    'Anomaly_Detection\AD-003_Accounts_with_Suspicious_Logon_Patterns\adsi.ps1',
    'Domain_Configuration\DCONF-007_Domains_with_Weak_Kerberos_Encryption\adsi.ps1',
    'Domain_Configuration\DCONF-008_Domains_with_Insecure_LDAP_Signing\adsi.ps1',
    'Domain_Controllers\DC-007_DCs_with_Insecure_SMB_Signing\adsi.ps1',
    'Domain_Controllers\DC-013_DCs_Replication_Failures\adsi.ps1',
    'Domain_Controllers\DC-019_DCs_Not_Configured_for_Secure_Time_Sync\adsi.ps1',
    'Domain_Controllers\DC-025_DCs_with_Insecure_DNS_Configuration\adsi.ps1',
    'Domain_Controllers\DC-027_DCs_with_Excessive_Service_Accounts\adsi.ps1',
    'Domain_Controllers\DC-028_DCs_with_Old_DSRM_Password\adsi.ps1',
    'Group_Policy\GPO-051_SYSVOL_Credential_Content_Scan\adsi.ps1',
    'Security_Accounts\SECACCT-002_Password_Settings_Object_Inventory\adsi.ps1',
    'Trust_Relationships\TRST-031_ExtraSIDs_Cross_Forest_Attack_Surface\adsi.ps1'
)

$stats = @{
    processed = 0
    a1_fixed = 0
    a2_fixed = 0
    skipped = 0
    failed = 0
}

foreach ($filePath in $filesToFix) {
    if (-not (Test-Path $filePath)) {
        Write-Host "⚠ File not found: $filePath" -ForegroundColor Yellow
        $stats.skipped++
        continue
    }
    
    $stats.processed++
    Write-Host "[$($stats.processed)/$($filesToFix.Count)] Processing: $filePath" -ForegroundColor Cyan
    
    try {
        $content = Get-Content $filePath -Raw
        $originalContent = $content
        $modified = $false
        $a1Fixed = $false
        $a2Fixed = $false
        
        # ====================================================================
        # FIX A2: Add objectSid to PropertiesToLoad
        # ====================================================================
        if ($content -notmatch "'objectSid'" -and $content -notmatch '"objectSid"') {
            Write-Host "  [A2] Checking for PropertiesToLoad..." -ForegroundColor Yellow
            
            # Pattern 1: @('prop1', 'prop2') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
            if ($content -match "@\(([^)]+)\)\s*\|\s*ForEach-Object\s*\{\s*\[void\]\s*\`$\w+\.PropertiesToLoad\.Add\(\`$_\)\s*\}") {
                $content = $content -replace "(@\()([^)]+)(\)\s*\|\s*ForEach-Object\s*\{\s*\[void\]\s*\`$\w+\.PropertiesToLoad\.Add)", "`$1`$2, 'objectSid'`$3"
                $a2Fixed = $true
                Write-Host "  ✓ A2 fixed (pattern 1)" -ForegroundColor Green
            }
            # Pattern 2: $searcher.PropertiesToLoad.AddRange(@("prop1", "prop2"))
            elseif ($content -match '\.PropertiesToLoad\.AddRange\(@\(([^)]+)\)\)') {
                $content = $content -replace '(\.PropertiesToLoad\.AddRange\(@\()([^)]+)(\)\))', '$1$2, "objectSid"$3'
                $a2Fixed = $true
                Write-Host "  ✓ A2 fixed (pattern 2)" -ForegroundColor Green
            }
            else {
                Write-Host "  - No PropertiesToLoad pattern found" -ForegroundColor Gray
            }
        } else {
            Write-Host "  - objectSid already present" -ForegroundColor Gray
        }
        
        # ====================================================================
        # FIX A1: Store FindAll() in variable
        # ====================================================================
        # Look for patterns where FindAll() is directly piped or used in foreach
        
        # Pattern 1: $searcher.FindAll() | ForEach-Object
        if ($content -match '\$(\w+)\.FindAll\(\)\s*\|\s*ForEach-Object') {
            Write-Host "  [A1] Fixing FindAll() | ForEach-Object pattern..." -ForegroundColor Yellow
            
            # Replace with stored variable
            $content = $content -replace '(\$\w+)\.FindAll\(\)\s*\|\s*(ForEach-Object)', '$results = $1.FindAll()' + "`n    `$results | `$2"
            $a1Fixed = $true
            Write-Host "  ✓ A1 fixed (pattern 1)" -ForegroundColor Green
        }
        # Pattern 2: foreach ($item in $searcher.FindAll())
        elseif ($content -match 'foreach\s*\(\s*\$\w+\s+in\s+\$(\w+)\.FindAll\(\)\s*\)') {
            Write-Host "  [A1] Fixing foreach FindAll() pattern..." -ForegroundColor Yellow
            
            # Replace with stored variable
            $content = $content -replace '(foreach\s*\(\s*\$\w+\s+in\s+)(\$\w+)\.FindAll\(\)(\s*\))', '$results = $2.FindAll()' + "`n    `$1`$results`$3"
            $a1Fixed = $true
            Write-Host "  ✓ A1 fixed (pattern 2)" -ForegroundColor Green
        }
        # Pattern 3: $variable = $searcher.FindAll() (already correct, but check for multiple searchers)
        elseif ($content -match '\$\w+\s*=\s*\$\w+\.FindAll\(\)') {
            Write-Host "  - FindAll() already stored correctly" -ForegroundColor Gray
        }
        else {
            Write-Host "  - No A1 issue pattern found" -ForegroundColor Gray
        }
        
        # Track modifications
        if ($a1Fixed) {
            $stats.a1_fixed++
            $modified = $true
        }
        if ($a2Fixed) {
            $stats.a2_fixed++
            $modified = $true
        }
        
        # Save if modified
        if ($modified) {
            if (-not $DryRun) {
                # Backup
                $backupPath = Join-Path $backupDir ($filePath -replace '\\', '_')
                Copy-Item $filePath $backupPath -Force
                
                # Save
                Set-Content $filePath -Value $content -NoNewline
            }
            Write-Host "  ✓ File updated" -ForegroundColor Green
        } else {
            Write-Host "  - No changes needed" -ForegroundColor Gray
        }
        
    } catch {
        Write-Host "  ✗ Error: $_" -ForegroundColor Red
        $stats.failed++
    }
    
    Write-Host ""
}

Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Files processed: $($stats.processed)"
Write-Host "Files skipped: $($stats.skipped)"
Write-Host "A1 fixes applied: $($stats.a1_fixed)"
Write-Host "A2 fixes applied: $($stats.a2_fixed)"
Write-Host "Failed: $($stats.failed)"

if (-not $DryRun) {
    Write-Host "`nBackup location: $backupDir" -ForegroundColor Green
    Write-Host "`nFIXES APPLIED - Run audit script to verify" -ForegroundColor Green
} else {
    Write-Host "`nDRY RUN - No changes made" -ForegroundColor Yellow
    Write-Host "Run without -DryRun to apply fixes" -ForegroundColor Yellow
}
