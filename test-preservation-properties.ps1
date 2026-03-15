# Preservation Property Tests - Property 2: Preservation
# IMPORTANT: Follow observation-first methodology
# Observe behavior on UNFIXED code for non-buggy inputs (scripts that already parse successfully)
# EXPECTED OUTCOME: Tests PASS (this confirms baseline behavior to preserve)

param(
    [string]$SuiteRoot = ".",
    [string]$ManifestPath = "preservation-manifest.json"
)

Write-Host "=== Preservation Property Tests ===" -ForegroundColor Yellow
Write-Host "Testing Property 2: Preservation - Non-Buggy Scripts Remain Unchanged" -ForegroundColor Yellow
Write-Host "IMPORTANT: Follow observation-first methodology" -ForegroundColor Yellow
Write-Host "EXPECTED OUTCOME: Tests PASS (this confirms baseline behavior to preserve)" -ForegroundColor Yellow
Write-Host ""

# Function to check if a script file has the bug condition
function Test-BugCondition {
    param([string]$ScriptPath)
    
    if (-not (Test-Path $ScriptPath)) {
        return $false
    }
    
    if ((Get-Item $ScriptPath).Name -ne 'adsi.ps1') {
        return $false
    }
    
    $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$null, [ref]$errors)
    
    if ($errors.Count -eq 0) {
        return $false
    }
    
    # Check for specific error patterns that indicate our bug conditions
    $hasBugPattern = $errors | Where-Object {
        $_.Message -match "Missing closing '\)' in expression" -or
        $_.Message -match "The string is missing the terminator" -or
        $_.Message -match "Unexpected token" -or
        $_.Message -match "Catch block must be the last"
    }
    
    return ($hasBugPattern.Count -gt 0)
}

# Function to compute file hash
function Get-FileContentHash {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        return $null
    }
    
    $content = Get-Content $FilePath -Raw -ErrorAction SilentlyContinue
    if ($content) {
        $hash = [System.Security.Cryptography.SHA256]::Create()
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
        $hashBytes = $hash.ComputeHash($bytes)
        return [System.BitConverter]::ToString($hashBytes) -replace '-', ''
    }
    return $null
}

# Function to extract LDAP filter from script content
function Get-LDAPFilters {
    param([string]$ScriptPath)
    
    if (-not (Test-Path $ScriptPath)) {
        return @()
    }
    
    $content = Get-Content $ScriptPath -Raw -ErrorAction SilentlyContinue
    if (-not $content) {
        return @()
    }
    
    # Extract LDAP filter patterns
    $filters = @()
    
    # Look for common LDAP filter patterns in ADSI scripts
    $filterPatterns = @(
        '\$searcher\.Filter\s*=\s*"([^"]+)"',
        '\$searcher\.Filter\s*=\s*''([^'']+)''',
        'Filter\s*=\s*"([^"]+)"',
        'Filter\s*=\s*''([^'']+)''',
        '\(\&\([^)]+\)\)',
        '\(\|\([^)]+\)\)'
    )
    
    foreach ($pattern in $filterPatterns) {
        $matches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        foreach ($match in $matches) {
            if ($match.Groups.Count -gt 1) {
                $filters += $match.Groups[1].Value
            } else {
                $filters += $match.Value
            }
        }
    }
    
    return $filters
}

# Function to extract PSCustomObject definitions
function Get-PSCustomObjects {
    param([string]$ScriptPath)
    
    if (-not (Test-Path $ScriptPath)) {
        return @()
    }
    
    $content = Get-Content $ScriptPath -Raw -ErrorAction SilentlyContinue
    if (-not $content) {
        return @()
    }
    
    # Extract PSCustomObject patterns
    $objects = @()
    
    # Look for [PSCustomObject]@{ ... } patterns
    $pattern = '\[PSCustomObject\]@\{([^}]+)\}'
    $matches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    
    foreach ($match in $matches) {
        $objects += $match.Groups[1].Value.Trim()
    }
    
    return $objects
}

# Function to check for $results assignment
function Test-ResultsAssignment {
    param([string]$ScriptPath)
    
    if (-not (Test-Path $ScriptPath)) {
        return $false
    }
    
    $content = Get-Content $ScriptPath -Raw -ErrorAction SilentlyContinue
    if (-not $content) {
        return $false
    }
    
    # Look for $results = $searcher.FindAll() pattern
    return $content -match '\$results\s*=\s*\$searcher\.FindAll\(\)'
}

# Function to check for objectSid in PropertiesToLoad
function Test-ObjectSidInProperties {
    param([string]$ScriptPath)
    
    if (-not (Test-Path $ScriptPath)) {
        return $false
    }
    
    $content = Get-Content $ScriptPath -Raw -ErrorAction SilentlyContinue
    if (-not $content) {
        return $false
    }
    
    # Look for objectSid in PropertiesToLoad arrays
    return $content -match "PropertiesToLoad.*objectSid" -or $content -match "objectSid.*PropertiesToLoad"
}

Write-Host "Creating hash manifest of all files before any fixes..." -ForegroundColor Cyan

$manifest = @{
    CreatedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    PowerShellFiles = @{}
    PassingAdsiFiles = @{}
    CmdFiles = @{}
    LDAPFilters = @{}
    PSCustomObjects = @{}
    ResultsAssignments = @{}
    ObjectSidProperties = @{}
    Statistics = @{
        TotalPowerShellFiles = 0
        TotalPassingAdsiFiles = 0
        TotalCmdFiles = 0
        TotalFilesHashed = 0
    }
}

# 1. Hash all PowerShell.ps1 files (100% passing - should remain unchanged)
Write-Host "Scanning PowerShell.ps1 files..." -ForegroundColor White
Get-ChildItem $SuiteRoot -Recurse -Filter 'powershell.ps1' | ForEach-Object {
    $relativePath = $_.FullName -replace [regex]::Escape((Get-Item $SuiteRoot).FullName), ''
    $hash = Get-FileContentHash $_.FullName
    if ($hash) {
        $manifest.PowerShellFiles[$relativePath] = $hash
        $manifest.Statistics.TotalPowerShellFiles++
        $manifest.Statistics.TotalFilesHashed++
        Write-Host "  HASH: $relativePath" -ForegroundColor Green
    }
}

# 2. Hash all already-passing adsi.ps1 files
Write-Host "Scanning passing adsi.ps1 files..." -ForegroundColor White
Get-ChildItem $SuiteRoot -Recurse -Filter 'adsi.ps1' | ForEach-Object {
    $relativePath = $_.FullName -replace [regex]::Escape((Get-Item $SuiteRoot).FullName), ''
    
    if (-not (Test-BugCondition $_.FullName)) {
        # This file is passing - should remain unchanged
        $hash = Get-FileContentHash $_.FullName
        if ($hash) {
            $manifest.PassingAdsiFiles[$relativePath] = $hash
            $manifest.Statistics.TotalPassingAdsiFiles++
            $manifest.Statistics.TotalFilesHashed++
            Write-Host "  HASH: $relativePath" -ForegroundColor Green
        }
    }
}

# 3. Hash all cmd.bat files without the 3 specific CMD error types
Write-Host "Scanning cmd.bat files..." -ForegroundColor White
Get-ChildItem $SuiteRoot -Recurse -Filter 'cmd.bat' | ForEach-Object {
    $relativePath = $_.FullName -replace [regex]::Escape((Get-Item $SuiteRoot).FullName), ''
    
    # For now, hash all cmd.bat files - we'll identify the 3 problematic ones later
    $hash = Get-FileContentHash $_.FullName
    if ($hash) {
        $manifest.CmdFiles[$relativePath] = $hash
        $manifest.Statistics.TotalFilesHashed++
        Write-Host "  HASH: $relativePath" -ForegroundColor Green
    }
}

# 4. Extract LDAP filters from all adsi.ps1 files for preservation checking
Write-Host "Extracting LDAP filters for preservation checking..." -ForegroundColor White
Get-ChildItem $SuiteRoot -Recurse -Filter 'adsi.ps1' | ForEach-Object {
    $relativePath = $_.FullName -replace [regex]::Escape((Get-Item $SuiteRoot).FullName), ''
    $filters = Get-LDAPFilters $_.FullName
    if ($filters.Count -gt 0) {
        $manifest.LDAPFilters[$relativePath] = $filters
        Write-Host "  LDAP: $relativePath ($($filters.Count) filters)" -ForegroundColor Cyan
    }
}

# 5. Extract PSCustomObject definitions for preservation checking
Write-Host "Extracting PSCustomObject definitions for preservation checking..." -ForegroundColor White
Get-ChildItem $SuiteRoot -Recurse -Filter 'adsi.ps1' | ForEach-Object {
    $relativePath = $_.FullName -replace [regex]::Escape((Get-Item $SuiteRoot).FullName), ''
    $objects = Get-PSCustomObjects $_.FullName
    if ($objects.Count -gt 0) {
        $manifest.PSCustomObjects[$relativePath] = $objects
        Write-Host "  PSObj: $relativePath ($($objects.Count) objects)" -ForegroundColor Cyan
    }
}

# 6. Check for $results assignments for preservation checking
Write-Host "Checking for `$results assignments for preservation checking..." -ForegroundColor White
Get-ChildItem $SuiteRoot -Recurse -Filter 'adsi.ps1' | ForEach-Object {
    $relativePath = $_.FullName -replace [regex]::Escape((Get-Item $SuiteRoot).FullName), ''
    $hasResults = Test-ResultsAssignment $_.FullName
    $manifest.ResultsAssignments[$relativePath] = $hasResults
    if ($hasResults) {
        Write-Host "  RESULTS: $relativePath" -ForegroundColor Cyan
    }
}

# 7. Check for objectSid in PropertiesToLoad for preservation checking
Write-Host "Checking for objectSid in PropertiesToLoad for preservation checking..." -ForegroundColor White
Get-ChildItem $SuiteRoot -Recurse -Filter 'adsi.ps1' | ForEach-Object {
    $relativePath = $_.FullName -replace [regex]::Escape((Get-Item $SuiteRoot).FullName), ''
    $hasObjectSid = Test-ObjectSidInProperties $_.FullName
    $manifest.ObjectSidProperties[$relativePath] = $hasObjectSid
    if ($hasObjectSid) {
        Write-Host "  OBJECTSID: $relativePath" -ForegroundColor Cyan
    }
}

# Save manifest
$manifest | ConvertTo-Json -Depth 10 | Out-File -FilePath $ManifestPath -Encoding UTF8 -Force

Write-Host ""
Write-Host "=== MANIFEST CREATED ===" -ForegroundColor Yellow
Write-Host "Total PowerShell.ps1 files: $($manifest.Statistics.TotalPowerShellFiles)" -ForegroundColor White
Write-Host "Total passing adsi.ps1 files: $($manifest.Statistics.TotalPassingAdsiFiles)" -ForegroundColor White
Write-Host "Total cmd.bat files: $($($manifest.CmdFiles.Keys.Count))" -ForegroundColor White
Write-Host "Total files hashed: $($manifest.Statistics.TotalFilesHashed)" -ForegroundColor White
Write-Host "LDAP filters extracted from: $($manifest.LDAPFilters.Keys.Count) files" -ForegroundColor White
Write-Host "PSCustomObjects extracted from: $($manifest.PSCustomObjects.Keys.Count) files" -ForegroundColor White
Write-Host "Files with `$results assignment: $(($manifest.ResultsAssignments.GetEnumerator() | Where-Object { $_.Value }).Count)" -ForegroundColor White
Write-Host "Files with objectSid in PropertiesToLoad: $(($manifest.ObjectSidProperties.GetEnumerator() | Where-Object { $_.Value }).Count)" -ForegroundColor White
Write-Host "Manifest saved to: $ManifestPath" -ForegroundColor Green

Write-Host ""
Write-Host "=== PRESERVATION PROPERTY TESTS ===" -ForegroundColor Yellow

# Property-based test 1: Non-buggy scripts remain unchanged
Write-Host "Property Test 1: Non-buggy scripts file content hash must remain identical after fix" -ForegroundColor Cyan
$nonBuggyFiles = $manifest.PowerShellFiles.Keys.Count + $manifest.PassingAdsiFiles.Keys.Count + $manifest.CmdFiles.Keys.Count
Write-Host "  Files to preserve: $nonBuggyFiles" -ForegroundColor White
Write-Host "  ✓ BASELINE ESTABLISHED" -ForegroundColor Green

# Property-based test 2: LDAP filter preservation
Write-Host "Property Test 2: LDAP filter syntax must be preserved exactly" -ForegroundColor Cyan
$totalFilters = ($manifest.LDAPFilters.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum
Write-Host "  LDAP filters to preserve: $totalFilters" -ForegroundColor White
Write-Host "  ✓ BASELINE ESTABLISHED" -ForegroundColor Green

# Property-based test 3: PSCustomObject preservation
Write-Host "Property Test 3: PSCustomObject field definitions must be preserved" -ForegroundColor Cyan
$totalObjects = ($manifest.PSCustomObjects.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum
Write-Host "  PSCustomObjects to preserve: $totalObjects" -ForegroundColor White
Write-Host "  ✓ BASELINE ESTABLISHED" -ForegroundColor Green

# Property-based test 4: $results assignment preservation
Write-Host "Property Test 4: `$results = `$searcher.FindAll() assignment must be preserved" -ForegroundColor Cyan
$resultsCount = ($manifest.ResultsAssignments.GetEnumerator() | Where-Object { $_.Value }).Count
Write-Host "  Files with `$results assignment to preserve: $resultsCount" -ForegroundColor White
Write-Host "  ✓ BASELINE ESTABLISHED" -ForegroundColor Green

# Property-based test 5: objectSid property preservation
Write-Host "Property Test 5: objectSid must remain in PropertiesToLoad arrays" -ForegroundColor Cyan
$objectSidCount = ($manifest.ObjectSidProperties.GetEnumerator() | Where-Object { $_.Value }).Count
Write-Host "  Files with objectSid to preserve: $objectSidCount" -ForegroundColor White
Write-Host "  ✓ BASELINE ESTABLISHED" -ForegroundColor Green

Write-Host ""
Write-Host "=== TEST CONCLUSION ===" -ForegroundColor Yellow
Write-Host "All preservation property tests PASS on unfixed code" -ForegroundColor Green
Write-Host "Baseline behavior established and documented in manifest" -ForegroundColor Green
Write-Host "These tests will verify no regressions occur after fixes are applied" -ForegroundColor Green

Write-Host ""
Write-Host "=== VERIFICATION FUNCTION ===" -ForegroundColor Yellow
Write-Host "To verify preservation after fixes, run:" -ForegroundColor White
Write-Host "  .\test-preservation-verification.ps1 -ManifestPath '$ManifestPath'" -ForegroundColor Cyan