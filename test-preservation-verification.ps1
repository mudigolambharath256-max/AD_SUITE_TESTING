# Preservation Verification Test
# IMPORTANT: Re-run the SAME tests from preservation properties - do NOT write new tests
# Run preservation property tests from step 2
# EXPECTED OUTCOME: Tests PASS (confirms no regressions)

param(
    [string]$SuiteRoot = ".",
    [string]$ManifestPath = "preservation-manifest.json"
)

Write-Host "=== Preservation Verification Test ===" -ForegroundColor Yellow
Write-Host "IMPORTANT: Re-run the SAME tests from preservation properties" -ForegroundColor Yellow
Write-Host "EXPECTED OUTCOME: Tests PASS (confirms no regressions)" -ForegroundColor Yellow
Write-Host ""

if (-not (Test-Path $ManifestPath)) {
    Write-Host "ERROR: Manifest file not found: $ManifestPath" -ForegroundColor Red
    Write-Host "Please run test-preservation-properties.ps1 first to create the baseline manifest" -ForegroundColor Red
    exit 1
}

# Load the baseline manifest
$manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json

Write-Host "Loading baseline manifest created at: $($manifest.CreatedAt)" -ForegroundColor Cyan
Write-Host ""

# Function to compute file hash (same as baseline)
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

# Function to extract LDAP filter from script content (same as baseline)
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

# Function to extract PSCustomObject definitions (same as baseline)
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

# Function to check for $results assignment (same as baseline)
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

# Function to check for objectSid in PropertiesToLoad (same as baseline)
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

$testResults = @{
    FileHashComparison = @{ Pass = 0; Fail = 0; Details = @() }
    LDAPFilterPreservation = @{ Pass = 0; Fail = 0; Details = @() }
    PSCustomObjectPreservation = @{ Pass = 0; Fail = 0; Details = @() }
    ResultsAssignmentPreservation = @{ Pass = 0; Fail = 0; Details = @() }
    ObjectSidPreservation = @{ Pass = 0; Fail = 0; Details = @() }
}

Write-Host "=== VERIFICATION TESTS ===" -ForegroundColor Yellow

# Test 1: File hash comparison
Write-Host "Test 1: File hash comparison (PowerShell.ps1, passing adsi.ps1, cmd.bat)" -ForegroundColor Cyan

# Check PowerShell.ps1 files
foreach ($relativePath in $manifest.PowerShellFiles.PSObject.Properties.Name) {
    $fullPath = Join-Path $SuiteRoot $relativePath.TrimStart('\')
    $currentHash = Get-FileContentHash $fullPath
    $baselineHash = $manifest.PowerShellFiles.$relativePath
    
    if ($currentHash -eq $baselineHash) {
        $testResults.FileHashComparison.Pass++
        Write-Host "  ✓ UNCHANGED: $relativePath" -ForegroundColor Green
    } else {
        $testResults.FileHashComparison.Fail++
        $testResults.FileHashComparison.Details += "PowerShell.ps1 file modified: $relativePath"
        Write-Host "  ✗ MODIFIED: $relativePath" -ForegroundColor Red
    }
}

# Check passing adsi.ps1 files
foreach ($relativePath in $manifest.PassingAdsiFiles.PSObject.Properties.Name) {
    $fullPath = Join-Path $SuiteRoot $relativePath.TrimStart('\')
    $currentHash = Get-FileContentHash $fullPath
    $baselineHash = $manifest.PassingAdsiFiles.$relativePath
    
    if ($currentHash -eq $baselineHash) {
        $testResults.FileHashComparison.Pass++
        Write-Host "  ✓ UNCHANGED: $relativePath" -ForegroundColor Green
    } else {
        $testResults.FileHashComparison.Fail++
        $testResults.FileHashComparison.Details += "Passing adsi.ps1 file modified: $relativePath"
        Write-Host "  ✗ MODIFIED: $relativePath" -ForegroundColor Red
    }
}

# Check cmd.bat files (excluding the 3 with known errors)
$knownCmdErrors = @('*SVC-*', '*DC-013*', '*TRST-031*')
foreach ($relativePath in $manifest.CmdFiles.PSObject.Properties.Name) {
    $shouldBeUnchanged = $true
    foreach ($errorPattern in $knownCmdErrors) {
        if ($relativePath -like $errorPattern) {
            $shouldBeUnchanged = $false
            break
        }
    }
    
    if ($shouldBeUnchanged) {
        $fullPath = Join-Path $SuiteRoot $relativePath.TrimStart('\')
        $currentHash = Get-FileContentHash $fullPath
        $baselineHash = $manifest.CmdFiles.$relativePath
        
        if ($currentHash -eq $baselineHash) {
            $testResults.FileHashComparison.Pass++
            Write-Host "  ✓ UNCHANGED: $relativePath" -ForegroundColor Green
        } else {
            $testResults.FileHashComparison.Fail++
            $testResults.FileHashComparison.Details += "CMD file modified: $relativePath"
            Write-Host "  ✗ MODIFIED: $relativePath" -ForegroundColor Red
        }
    }
}

# Test 2: LDAP filter preservation
Write-Host ""
Write-Host "Test 2: LDAP filter preservation across all fixed scripts" -ForegroundColor Cyan
foreach ($relativePath in $manifest.LDAPFilters.PSObject.Properties.Name) {
    $fullPath = Join-Path $SuiteRoot $relativePath.TrimStart('\')
    $currentFilters = Get-LDAPFilters $fullPath
    $baselineFilters = $manifest.LDAPFilters.$relativePath
    
    $filtersMatch = $true
    if ($currentFilters.Count -ne $baselineFilters.Count) {
        $filtersMatch = $false
    } else {
        for ($i = 0; $i -lt $currentFilters.Count; $i++) {
            if ($currentFilters[$i] -ne $baselineFilters[$i]) {
                $filtersMatch = $false
                break
            }
        }
    }
    
    if ($filtersMatch) {
        $testResults.LDAPFilterPreservation.Pass++
        Write-Host "  ✓ PRESERVED: $relativePath ($($currentFilters.Count) filters)" -ForegroundColor Green
    } else {
        $testResults.LDAPFilterPreservation.Fail++
        $testResults.LDAPFilterPreservation.Details += "LDAP filters changed: $relativePath"
        Write-Host "  ✗ CHANGED: $relativePath" -ForegroundColor Red
    }
}

# Test 3: PSCustomObject preservation
Write-Host ""
Write-Host "Test 3: PSCustomObject field preservation across all fixed scripts" -ForegroundColor Cyan
foreach ($relativePath in $manifest.PSCustomObjects.PSObject.Properties.Name) {
    $fullPath = Join-Path $SuiteRoot $relativePath.TrimStart('\')
    $currentObjects = Get-PSCustomObjects $fullPath
    $baselineObjects = $manifest.PSCustomObjects.$relativePath
    
    $objectsMatch = $true
    if ($currentObjects.Count -ne $baselineObjects.Count) {
        $objectsMatch = $false
    } else {
        for ($i = 0; $i -lt $currentObjects.Count; $i++) {
            if ($currentObjects[$i] -ne $baselineObjects[$i]) {
                $objectsMatch = $false
                break
            }
        }
    }
    
    if ($objectsMatch) {
        $testResults.PSCustomObjectPreservation.Pass++
        Write-Host "  ✓ PRESERVED: $relativePath ($($currentObjects.Count) objects)" -ForegroundColor Green
    } else {
        $testResults.PSCustomObjectPreservation.Fail++
        $testResults.PSCustomObjectPreservation.Details += "PSCustomObjects changed: $relativePath"
        Write-Host "  ✗ CHANGED: $relativePath" -ForegroundColor Red
    }
}

# Test 4: $results assignment preservation
Write-Host ""
Write-Host "Test 4: `$results assignment preservation across all fixed scripts" -ForegroundColor Cyan
foreach ($relativePath in $manifest.ResultsAssignments.PSObject.Properties.Name) {
    $fullPath = Join-Path $SuiteRoot $relativePath.TrimStart('\')
    $currentHasResults = Test-ResultsAssignment $fullPath
    $baselineHasResults = $manifest.ResultsAssignments.$relativePath
    
    if ($currentHasResults -eq $baselineHasResults) {
        $testResults.ResultsAssignmentPreservation.Pass++
        if ($currentHasResults) {
            Write-Host "  ✓ PRESERVED: $relativePath (has `$results)" -ForegroundColor Green
        } else {
            Write-Host "  ✓ PRESERVED: $relativePath (no `$results)" -ForegroundColor Green
        }
    } else {
        $testResults.ResultsAssignmentPreservation.Fail++
        $testResults.ResultsAssignmentPreservation.Details += "`$results assignment changed: $relativePath"
        Write-Host "  ✗ CHANGED: $relativePath" -ForegroundColor Red
    }
}

# Test 5: objectSid property preservation
Write-Host ""
Write-Host "Test 5: objectSid property preservation in all PropertiesToLoad arrays" -ForegroundColor Cyan
foreach ($relativePath in $manifest.ObjectSidProperties.PSObject.Properties.Name) {
    $fullPath = Join-Path $SuiteRoot $relativePath.TrimStart('\')
    $currentHasObjectSid = Test-ObjectSidInProperties $fullPath
    $baselineHasObjectSid = $manifest.ObjectSidProperties.$relativePath
    
    if ($currentHasObjectSid -eq $baselineHasObjectSid) {
        $testResults.ObjectSidPreservation.Pass++
        if ($currentHasObjectSid) {
            Write-Host "  ✓ PRESERVED: $relativePath (has objectSid)" -ForegroundColor Green
        } else {
            Write-Host "  ✓ PRESERVED: $relativePath (no objectSid)" -ForegroundColor Green
        }
    } else {
        $testResults.ObjectSidPreservation.Fail++
        $testResults.ObjectSidPreservation.Details += "objectSid property changed: $relativePath"
        Write-Host "  ✗ CHANGED: $relativePath" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== VERIFICATION RESULTS ===" -ForegroundColor Yellow

$allTestsPassed = $true

Write-Host "File Hash Comparison: $($testResults.FileHashComparison.Pass) PASS, $($testResults.FileHashComparison.Fail) FAIL" -ForegroundColor White
if ($testResults.FileHashComparison.Fail -gt 0) { $allTestsPassed = $false }

Write-Host "LDAP Filter Preservation: $($testResults.LDAPFilterPreservation.Pass) PASS, $($testResults.LDAPFilterPreservation.Fail) FAIL" -ForegroundColor White
if ($testResults.LDAPFilterPreservation.Fail -gt 0) { $allTestsPassed = $false }

Write-Host "PSCustomObject Preservation: $($testResults.PSCustomObjectPreservation.Pass) PASS, $($testResults.PSCustomObjectPreservation.Fail) FAIL" -ForegroundColor White
if ($testResults.PSCustomObjectPreservation.Fail -gt 0) { $allTestsPassed = $false }

Write-Host "`$results Assignment Preservation: $($testResults.ResultsAssignmentPreservation.Pass) PASS, $($testResults.ResultsAssignmentPreservation.Fail) FAIL" -ForegroundColor White
if ($testResults.ResultsAssignmentPreservation.Fail -gt 0) { $allTestsPassed = $false }

Write-Host "objectSid Property Preservation: $($testResults.ObjectSidPreservation.Pass) PASS, $($testResults.ObjectSidPreservation.Fail) FAIL" -ForegroundColor White
if ($testResults.ObjectSidPreservation.Fail -gt 0) { $allTestsPassed = $false }

Write-Host ""
if ($allTestsPassed) {
    Write-Host "=== ALL PRESERVATION TESTS PASS ===" -ForegroundColor Green
    Write-Host "No regressions detected - all preservation requirements met" -ForegroundColor Green
    exit 0
} else {
    Write-Host "=== PRESERVATION TESTS FAILED ===" -ForegroundColor Red
    Write-Host "Regressions detected:" -ForegroundColor Red
    
    foreach ($category in $testResults.Keys) {
        if ($testResults[$category].Details.Count -gt 0) {
            Write-Host "  $category`:" -ForegroundColor Red
            foreach ($detail in $testResults[$category].Details) {
                Write-Host "    - $detail" -ForegroundColor Red
            }
        }
    }
    exit 1
}