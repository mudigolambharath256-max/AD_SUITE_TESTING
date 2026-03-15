# Fix Pattern G: TRST files with try-catch and brace issues
# Issues: malformed ForEach-Object line + extra closing brace + corrupted BloodHound export

Write-Host "=== Fixing Pattern G: TRST Try-Catch Issues ===" -ForegroundColor Cyan

# Get all TRST files that have Pattern G issues (excluding the one we already fixed)
$trstFiles = Get-ChildItem -Path "Trust_Relationships" -Filter "adsi.ps1" -Recurse | Where-Object { 
    $_.Directory.Name -match "TRST-" -and $_.Directory.Name -ne "TRST-005_External_Trusts_Non-Forest"
}

Write-Host "Found $($trstFiles.Count) TRST files to check and fix" -ForegroundColor Yellow
Write-Host ""

$fixedCount = 0

foreach ($file in $trstFiles) {
    Write-Host "Processing: $($file.Directory.Name)" -ForegroundColor Gray
    
    # Check if file has Pattern G errors
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$errors)
    
    $hasPatternG = $false
    if ($errors) {
        foreach ($error in $errors) {
            if (($error.Extent.StartLineNumber -eq 22 -and $error.Message -match "Try statement.*missing.*Catch.*Finally") -or
                ($error.Extent.StartLineNumber -eq 164 -and $error.Message -match "Unexpected token.*}")) {
                $hasPatternG = $true
                break
            }
        }
    }
    
    if ($hasPatternG) {
        Write-Host "  ✗ Has Pattern G errors - fixing..." -ForegroundColor Yellow
        
        # Read the original file to extract key information
        $content = Get-Content -Path $file.FullName -Raw
        
        # Extract the check ID from the directory name
        $checkId = $file.Directory.Name.Split('_')[0]
        
        # Extract the check name and other details from the file header
        $checkName = ""
        $severity = "high"
        
        if ($content -match '# Check: (.+)') {
            $checkName = $matches[1]
        }
        if ($content -match '# Severity: (\w+)') {
            $severity = $matches[1]
        }
        
        # Extract the LDAP filter from the searcher line
        $ldapFilter = ""
        if ($content -match '\$searcher = \[ADSISearcher\]''([^'']+)''') {
            $ldapFilter = $matches[1]
        }
        
        # Create clean content based on the template
        $cleanContent = @"
# Check: $checkName
# Category: Trust Relationships
# Severity: $severity
# ID: $checkId
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)

# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP
# FalsePositiveRisk   : Low
# ─────────────────────────────────────────────

try {
`$searcher = [ADSISearcher]'$ldapFilter'
`$searcher.PageSize = 1000
`$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'trustAttributes', 'trustDirection', 'trustType', 'trustPartner', 'flatName', 'whenCreated', 'whenChanged', 'objectSid', 'samAccountName') | ForEach-Object {
    [void]`$searcher.PropertiesToLoad.Add(`$_)
}

`$results = `$searcher.FindAll()
Write-Host "Found `$(`$results.Count) objects" -ForegroundColor Cyan

`$output = `$results | ForEach-Object {
  `$p = `$_.Properties
  [PSCustomObject]@{
    Label = '$checkName'
    Name = if (`$p['name'] -and `$p['name'].Count -gt 0) { `$p['name'][0] } else { 'N/A' }
    DistinguishedName = if (`$p['distinguishedname'] -and `$p['distinguishedname'].Count -gt 0) { `$p['distinguishedname'][0] } else { 'N/A' }
  }
}

`$results.Dispose()
`$searcher.Dispose()

if (`$output) { `$output | Format-Table -AutoSize }
else { Write-Host 'No findings' -ForegroundColor Gray }

} catch {
    Write-Error "AD query failed: `$_"
    exit 1
}

# ============================================================================
# BLOODHOUND EXPORT BLOCK
# ============================================================================
# Automatically export results to BloodHound-compatible JSON format
# ============================================================================

try {
    # Initialize session
    if (-not `$env:ADSUITE_SESSION_ID) {
        `$env:ADSUITE_SESSION_ID = Get-Date -Format 'yyyyMMdd_HHmmss'
        Write-Host "[BloodHound] New session: `$env:ADSUITE_SESSION_ID" -ForegroundColor Cyan
    }
    
    `$bhDir = "C:\ADSuite_BloodHound\SESSION_`$env:ADSUITE_SESSION_ID"
    if (-not (Test-Path `$bhDir)) {
        New-Item -ItemType Directory -Path `$bhDir -Force | Out-Null
    }
    
    # Convert results to BloodHound format
    if (`$results -and `$results.Count -gt 0) {
        `$bhNodes = @()
        
        foreach (`$item in `$results) {
            # Extract SID as ObjectIdentifier
            `$objectId = if (`$item.objectSid) {
                try {
                    (New-Object System.Security.Principal.SecurityIdentifier(`$item.objectSid, 0)).Value
                } catch {
                    `$item.DistinguishedName
                }
            } else {
                `$item.DistinguishedName
            }
            
            # Determine object type
            `$objectType = if (`$item.objectClass -contains 'user') { 'User' }
                         elseif (`$item.objectClass -contains 'computer') { 'Computer' }
                         elseif (`$item.objectClass -contains 'group') { 'Group' }
                         else { 'Base' }
            
            # Extract domain from DN
            `$domain = if (`$item.DistinguishedName -match 'DC=([^,]+)') {
                (`$matches[1..(`$matches.Count-1)] -join '.').ToUpper()
            } else { 'UNKNOWN' }
            
            `$bhNodes += @{
                ObjectIdentifier = `$objectId
                ObjectType = `$objectType
                Properties = @{
                    name = `$item.Name
                    distinguishedname = `$item.DistinguishedName
                    samaccountname = `$item.samAccountName
                    domain = `$domain
                    checkid = '$checkId'
                    severity = '$severity'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        `$bhOutput = @{ nodes = `$bhNodes } | ConvertTo-Json -Depth 10
        `$bhFile = Join-Path `$bhDir "${checkId}_nodes.json"
        Set-Content -Path `$bhFile -Value `$bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported `$(`$bhNodes.Count) nodes to: `$bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: `$_"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================
"@
        
        # Write the clean content to the file
        $cleanContent | Out-File -FilePath $file.FullName -Encoding UTF8 -NoNewline
        
        # Verify the fix
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$errors)
        
        if ($errors.Count -eq 0) {
            Write-Host "  ✓ Fixed successfully (0 errors)" -ForegroundColor Green
            $fixedCount++
        } else {
            Write-Host "  ✗ Still has $($errors.Count) errors:" -ForegroundColor Red
            $errors | Select-Object -First 2 | ForEach-Object {
                Write-Host "    Line $($_.Extent.StartLineNumber): $($_.Message)" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "  ✓ No Pattern G errors found" -ForegroundColor Green
    }
    
    Write-Host ""
}

Write-Host "Pattern G fix complete! Fixed $fixedCount files." -ForegroundColor Green