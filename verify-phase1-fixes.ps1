# ============================================================================
# Verify Phase 1 Fixes
# ============================================================================
# Quick verification script to check if A1 and A2 fixes were applied correctly
# ============================================================================

param([int]$SampleSize = 10)

Write-Host "=== Verifying Phase 1 Fixes ===" -ForegroundColor Cyan
Write-Host ""

$categories = Get-ChildItem -Directory | Where-Object { 
    $_.Name -notmatch '^(ad-suite-web|\.vscode|backups)' 
}

$adsiFiles = @()
foreach ($cat in $categories) {
    $checks = Get-ChildItem -Path $cat.FullName -Directory
    foreach ($check in $checks) {
        $adsiPath = Join-Path $check.FullName "adsi.ps1"
        if (Test-Path $adsiPath) {
            $adsiFiles += $adsiPath
        }
    }
}

# Sample random files
$sample = $adsiFiles | Get-Random -Count $SampleSize

$results = @{
    A1_pass = 0
    A1_fail = 0
    A2_pass = 0
    A2_fail = 0
}

foreach ($file in $sample) {
    $content = Get-Content $file -Raw
    $name = Split-Path $file -Leaf
    $parent = Split-Path (Split-Path $file -Parent) -Leaf
    
    Write-Host "Checking: $parent/$name" -ForegroundColor Yellow
    
    # Check A1
    if ($content -match '\$results\s*=\s*\$searcher\.FindAll\(\)') {
        Write-Host "  ✓ A1: FindAll() stored in variable" -ForegroundColor Green
        $results.A1_pass++
    } else {
        Write-Host "  ✗ A1: FindAll() NOT stored" -ForegroundColor Red
        $results.A1_fail++
    }
    
    # Check A2
    if ($content -match "PropertiesToLoad.*'objectSid'|PropertiesToLoad.*`"objectSid`"") {
        Write-Host "  ✓ A2: objectSid present" -ForegroundColor Green
        $results.A2_pass++
    } else {
        Write-Host "  ✗ A2: objectSid MISSING" -ForegroundColor Red
        $results.A2_fail++
    }
    Write-Host ""
}

Write-Host "=== Verification Summary ===" -ForegroundColor Cyan
Write-Host "Sample Size: $SampleSize files"
Write-Host ""
Write-Host "A1 (FindAll stored): PASS=$($results.A1_pass) FAIL=$($results.A1_fail)"
Write-Host "A2 (objectSid): PASS=$($results.A2_pass) FAIL=$($results.A2_fail)"
