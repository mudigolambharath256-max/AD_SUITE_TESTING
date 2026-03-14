# ============================================================================
# Fix Remaining A1 and A2 Issues
# ============================================================================
# Fixes the last 8 files with A1/A2 issues:
# - DC-013, DC-019, DC-025, DC-027, DC-028, GPO-051 (A1 + A2)
# - SECACCT-002, TRST-031 (A1 only)
# ============================================================================

param([switch]$DryRun)

$ErrorActionPreference = 'Stop'

Write-Host "=== Fixing Remaining A1/A2 Issues ===" -ForegroundColor Cyan
Write-Host "Mode: $(if ($DryRun) { 'DRY RUN' } else { 'LIVE' })`n" -ForegroundColor $(if ($DryRun) { 'Yellow' } else { 'Red' })

$backupDir = "backups_final_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
if (-not $DryRun) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    Write-Host "Backup directory: $backupDir`n" -ForegroundColor Green
}

$filesToFix = @(
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
    failed = 0
}

foreach ($filePath in $filesToFix) {
    if (-not (Test-Path $filePath)) {
        Write-Host "⚠ File not found: $filePath" -ForegroundColor Yellow
        continue
    }
    
    $stats.processed++
    Write-Host "Processing: $filePath" -ForegroundColor Cyan
    
    try {
        $content = Get-Content $filePath -Raw
        $originalContent = $content
        $modified = $false
        
        # ====================================================================
        # FIX A1: Store FindAll() in variable
        # ====================================================================
        # Pattern: $searcher.FindAll() | ForEach-Object
        # Replace: $results = $searcher.FindAll()
        #          $results | ForEach-Object
        
        if ($content -match '\$\w+Searcher\.FindAll\(\)\s*\|\s*ForEach-Object') {
            Write-Host "  [A1] Fixing FindAll() storage..." -ForegroundColor Yellow
            
            # Replace pattern: $xxxSearcher.FindAll() | ForEach-Object
            $content = $content -replace '(\$\w+Searcher)\.FindAll\(\)\s*\|\s*(ForEach-Object)', '$results = $1.FindAll()' + "`n`$results | `$2"
            
            if ($content -ne $originalContent) {
                $stats.a1_fixed++
                $modified = $true
                Write-Host "  ✓ A1 fixed" -ForegroundColor Green
            }
        }
        
        # ====================================================================
        # FIX A2: Add objectSid to PropertiesToLoad
        # ====================================================================
        # Find all PropertiesToLoad.Add patterns and add objectSid if missing
        
        if ($content -notmatch "'objectSid'" -and $content -notmatch '"objectSid"') {
            if ($content -match 'PropertiesToLoad') {
                Write-Host "  [A2] Adding objectSid..." -ForegroundColor Yellow
                
                # Pattern: @('prop1', 'prop2') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
                if ($content -match "@\(([^)]+)\)\s*\|\s*ForEach-Object\s*\{\s*\[void\]\s*\`$\w+Searcher\.PropertiesToLoad\.Add\(\`$_\)\s*\}") {
                    $content = $content -replace "(@\()([^)]+)(\)\s*\|\s*ForEach-Object\s*\{\s*\[void\]\s*\`$\w+Searcher\.PropertiesToLoad\.Add)", "`$1`$2, 'objectSid'`$3"
                    
                    if ($content -ne $originalContent) {
                        $stats.a2_fixed++
                        $modified = $true
                        Write-Host "  ✓ A2 fixed" -ForegroundColor Green
                    }
                }
            }
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
Write-Host "A1 fixes applied: $($stats.a1_fixed)"
Write-Host "A2 fixes applied: $($stats.a2_fixed)"
Write-Host "Failed: $($stats.failed)"

if (-not $DryRun) {
    Write-Host "`nBackup location: $backupDir" -ForegroundColor Green
    Write-Host "FIXES APPLIED" -ForegroundColor Green
} else {
    Write-Host "`nDRY RUN - No changes made" -ForegroundColor Yellow
}
