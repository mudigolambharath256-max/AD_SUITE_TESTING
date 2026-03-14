# ============================================================================
# Phase 4: Append BloodHound Export Block to All adsi.ps1 Files
# ============================================================================
# Adds BloodHound JSON export functionality to all 762 adsi.ps1 scripts
# ============================================================================

param([switch]$DryRun)

$ErrorActionPreference = 'Stop'

Write-Host "=== Phase 4: Appending BloodHound Export Block ===" -ForegroundColor Cyan
Write-Host "Mode: $(if ($DryRun) { 'DRY RUN' } else { 'LIVE' })`n" -ForegroundColor $(if ($DryRun) { 'Yellow' } else { 'Red' })

$backupDir = "backups_phase4_export_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
if (-not $DryRun) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    Write-Host "Backup directory: $backupDir`n" -ForegroundColor Green
}

$stats = @{
    processed = 0
    appended = 0
    skipped = 0
    failed = 0
}

# BloodHound export block template
$exportBlockTemplate = @'

# ============================================================================
# BLOODHOUND EXPORT BLOCK
# ============================================================================
# Automatically export results to BloodHound-compatible JSON format
# ============================================================================

try {
    # Initialize session
    if (-not $env:ADSUITE_SESSION_ID) {
        $env:ADSUITE_SESSION_ID = Get-Date -Format 'yyyyMMdd_HHmmss'
        Write-Host "[BloodHound] New session: $env:ADSUITE_SESSION_ID" -ForegroundColor Cyan
    }
    
    $bhDir = "C:\ADSuite_BloodHound\SESSION_$env:ADSUITE_SESSION_ID"
    if (-not (Test-Path $bhDir)) {
        New-Item -ItemType Directory -Path $bhDir -Force | Out-Null
    }
    
    # Convert results to BloodHound format
    if ($results -and $results.Count -gt 0) {
        $bhNodes = @()
        
        foreach ($item in $results) {
            # Extract SID as ObjectIdentifier
            $objectId = if ($item.objectSid) {
                try {
                    (New-Object System.Security.Principal.SecurityIdentifier($item.objectSid, 0)).Value
                } catch {
                    $item.DistinguishedName
                }
            } else {
                $item.DistinguishedName
            }
            
            # Determine object type
            $objectType = if ($item.objectClass -contains 'user') { 'User' }
                         elseif ($item.objectClass -contains 'computer') { 'Computer' }
                         elseif ($item.objectClass -contains 'group') { 'Group' }
                         else { 'Base' }
            
            # Extract domain from DN
            $domain = if ($item.DistinguishedName -match 'DC=([^,]+)') {
                ($matches[1..($matches.Count-1)] -join '.').ToUpper()
            } else { 'UNKNOWN' }
            
            $bhNodes += @{
                ObjectIdentifier = $objectId
                ObjectType = $objectType
                Properties = @{
                    name = $item.Name
                    distinguishedname = $item.DistinguishedName
                    samaccountname = $item.samAccountName
                    domain = $domain
                    checkid = '<<<CHECK_ID>>>'
                    severity = '<<<SEVERITY>>>'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "<<<CHECK_ID>>>_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: $_"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================
'@

# Find all adsi.ps1 files
$categories = Get-ChildItem -Directory | Where-Object { 
    $_.Name -notmatch '^(ad-suite-web|\.vscode|backups_)' 
}

foreach ($category in $categories) {
    $checks = Get-ChildItem -Path $category.FullName -Directory
    
    foreach ($check in $checks) {
        $filePath = Join-Path $check.FullName "adsi.ps1"
        
        if (-not (Test-Path $filePath)) {
            continue
        }
        
        $stats.processed++
        $relativePath = $filePath -replace [regex]::Escape($PWD.Path + '\'), ''
        
        if ($stats.processed % 50 -eq 0) {
            Write-Host "  Processed $($stats.processed) files..." -ForegroundColor Gray
        }
        
        try {
            $content = Get-Content $filePath -Raw
            
            # Check if export block already exists
            if ($content -match 'BLOODHOUND EXPORT BLOCK') {
                $stats.skipped++
                continue
            }
            
            # Extract CHECK_ID from filename or header
            $checkId = $check.Name -replace '_.*', ''
            
            # Extract SEVERITY from header comments
            $severity = 'MEDIUM'
            if ($content -match '# Severity:\s*(\w+)') {
                $severity = $matches[1]
            } elseif ($content -match '# SEVERITY:\s*(\w+)') {
                $severity = $matches[1]
            }
            
            # Create export block with CHECK_ID and SEVERITY
            $exportBlock = $exportBlockTemplate -replace '<<<CHECK_ID>>>', $checkId -replace '<<<SEVERITY>>>', $severity
            
            # Find insertion point - after the last output statement but before final output
            # Look for the last Format-Table or output line
            if ($content -match '(\$output\s*\|\s*Format-Table[^\r\n]*\r?\n)') {
                # Insert after Format-Table
                $content = $content -replace '(\$output\s*\|\s*Format-Table[^\r\n]*\r?\n)', "`$1`n$exportBlock`n"
            } elseif ($content -match '(\$output\s*\|\s*Select-Object[^\r\n]*\r?\n)') {
                # Insert after Select-Object
                $content = $content -replace '(\$output\s*\|\s*Select-Object[^\r\n]*\r?\n)', "`$1`n$exportBlock`n"
            } elseif ($content -match '(Write-Host.*\$output[^\r\n]*\r?\n)') {
                # Insert after Write-Host output
                $content = $content -replace '(Write-Host.*\$output[^\r\n]*\r?\n)', "`$1`n$exportBlock`n"
            } else {
                # Insert before the last closing brace or at end
                $content = $content.TrimEnd() + "`n`n$exportBlock`n"
            }
            
            $stats.appended++
            
            if (-not $DryRun) {
                # Backup
                $backupPath = Join-Path $backupDir ($relativePath -replace '\\', '_')
                Copy-Item $filePath $backupPath -Force
                
                # Save
                Set-Content $filePath -Value $content -NoNewline
            }
            
        } catch {
            Write-Host "  ✗ Error in $relativePath : $_" -ForegroundColor Red
            $stats.failed++
        }
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Files processed: $($stats.processed)"
Write-Host "Export blocks appended: $($stats.appended)"
Write-Host "Files skipped (already have export): $($stats.skipped)"
Write-Host "Failed: $($stats.failed)"

if (-not $DryRun -and $stats.appended -gt 0) {
    Write-Host "`nBackup location: $backupDir" -ForegroundColor Green
    Write-Host "BLOODHOUND EXPORT BLOCKS APPENDED" -ForegroundColor Green
} elseif ($DryRun) {
    Write-Host "`nDRY RUN - No changes made" -ForegroundColor Yellow
}
