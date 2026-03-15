# ============================================================================
# Fix ADSI Recovery + Append BloodHound Export Block
# ============================================================================
param(
    [Parameter(Mandatory=$false)]
    [string]$SuiteRoot = "C:\Users\acer\Downloads\AD_suiteXXX"
)

$ErrorActionPreference = 'Stop'
$recovered = 0
$failed = 0
$skipped = 0
$bhAppended = 0
$failList = [System.Collections.Generic.List[string]]::new()

Write-Host "=== ADSI Recovery + BH Export Append ===" -ForegroundColor Cyan
Write-Host "Suite root: $SuiteRoot"
Write-Host ""

# ── Helper: Get node type from LDAP filter ───────────────────────────────────
function Get-NodeType([string]$filter, [string]$category) {
    $f = $filter.ToLower()
    $c = $category.ToLower()
    if ($f -match 'objectcategory=person' -and $f -notmatch 'objectclass=computer') { return 'users' }
    if ($f -match 'objectcategory=computer|objectclass=computer') { return 'computers' }
    if ($f -match 'objectcategory=group|objectclass=group')       { return 'groups' }
    if ($f -match 'objectclass=domaindns|objectclass=domain(?!dns)') { return 'domains' }
    if ($f -match 'objectclass=grouppolicycontainer')             { return 'gpos' }
    if ($f -match 'objectclass=organizationalunit')               { return 'ous' }
    if ($f -match 'objectclass=pkicertificatetemplate|pkienrollmentservice') { return 'containers' }
    if ($f -match 'objectclass=trusteddomain')                    { return 'domains' }
    if ($f -match 'objectclass=attributeschema|classschema')      { return 'containers' }
    if ($f -match 'objectclass=site|objectclass=subnet|objectclass=sitelink') { return 'containers' }
    if ($c -match 'cert|pki')                                     { return 'containers' }
    if ($c -match 'trust')                                        { return 'domains' }
    if ($c -match 'computer|server')                              { return 'computers' }
    if ($c -match 'gpo|group_policy')                             { return 'gpos' }
    return 'users'
}

# ── Helper: Build BH export block ────────────────────────────────────────────
function Build-BhBlock([string]$checkId, [string]$checkName, [string]$severity,
                        [string]$category, [string]$nodeType) {
    $safeName = $checkName -replace "'","''"
    return @"

# ============================================================================
# BLOODHOUND EXPORT - BH CE v5
# ============================================================================
try {
    `$bhSession = if (`$env:ADSUITE_SESSION_ID) { `$env:ADSUITE_SESSION_ID } else { [guid]::NewGuid().ToString('N') }
    `$bhRoot    = if (`$env:ADSUITE_OUTPUT_ROOT) { `$env:ADSUITE_OUTPUT_ROOT } else { Join-Path `$env:TEMP 'ADSuite_Sessions' }
    `$bhDir     = Join-Path `$bhRoot (Join-Path `$bhSession 'bloodhound')
    if (-not (Test-Path `$bhDir)) { New-Item -ItemType Directory -Path `$bhDir -Force -ErrorAction Stop | Out-Null }
    `$bhNodes = [System.Collections.Generic.List[hashtable]]::new()
    foreach (`$r in `$results) {
        `$p    = `$r.Properties
        `$dn   = if (`$p['distinguishedname'].Count -gt 0) { [string]`$p['distinguishedname'][0] } else { '' }
        `$name = if (`$p['name'].Count -gt 0)              { [string]`$p['name'][0] }              else { '' }
        `$sam  = if (`$p['samaccountname'].Count -gt 0)    { [string]`$p['samaccountname'][0] }    else { '' }
        `$uac  = if (`$p['useraccountcontrol'].Count -gt 0) { [int]`$p['useraccountcontrol'][0] }  else { 0 }
        `$dom  = ((`$dn -split ',') | Where-Object { `$_ -match '^DC=' } |
                  ForEach-Object { (`$_ -replace '^DC=','').ToUpper() }) -join '.'
        `$oid  = if (`$dn) { `$dn.ToUpper() } else { [guid]::NewGuid().ToString() }
        `$sidRaw = if (`$p['objectsid'].Count -gt 0) { `$p['objectsid'][0] } else { `$null }
        if (`$sidRaw) { try { `$oid = (New-Object System.Security.Principal.SecurityIdentifier([byte[]]`$sidRaw, 0)).Value } catch { } }
        `$bhNodes.Add(@{
            ObjectIdentifier = `$oid
            Properties = @{
                name              = if (`$dom -and `$name) { "`$(`$name.ToUpper())@`$dom" } else { `$name.ToUpper() }
                domain            = `$dom
                distinguishedname = `$dn.ToUpper()
                samaccountname    = `$sam
                enabled           = -not (`$uac -band 2)
                adSuiteCheckId    = '$checkId'
                adSuiteCheckName  = '$safeName'
                adSuiteSeverity   = '$severity'
                adSuiteCategory   = '$category'
                adSuiteFlag       = `$true
            }
            Aces           = @()
            IsDeleted      = `$false
            IsACLProtected = `$false
        })
    }
    `$bhTs = Get-Date -Format 'yyyyMMdd_HHmmss'
    @{
        data = `$bhNodes.ToArray()
        meta = @{ type = '$nodeType'; count = `$bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress |
        Out-File -FilePath (Join-Path `$bhDir '${checkId}_`$bhTs.json') -Encoding UTF8 -Force
} catch { }
# ============================================================================
"@
}

# ── Find all check directories ───────────────────────────────────────────────
$checkDirs = Get-ChildItem -Path $SuiteRoot -Recurse -Directory | 
    Where-Object { $_.Name -match '^[A-Z]+-\d+' } |
    Where-Object { Test-Path (Join-Path $_.FullName 'combined_multiengine.ps1') }

Write-Host "Found $($checkDirs.Count) check directories with combined_multiengine.ps1"
Write-Host ""

foreach ($checkDir in $checkDirs) {
    $checkName = $checkDir.Name
    $combinedPath = Join-Path $checkDir.FullName 'combined_multiengine.ps1'
    $adsiPath = Join-Path $checkDir.FullName 'adsi.ps1'
    
    try {
        $combinedContent = Get-Content $combinedPath -Raw -ErrorAction Stop
        
        # Extract ADSI block
        $pattern = '\$adsiResults\s*=\s*@\(\s*\n(.*?)\n\s*\)\s*\n\s*\$results\s*\+=\s*\$adsiResults'
        $match = [regex]::Match($combinedContent, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
        
        if (-not $match.Success) {
            Write-Host "  SKIP: $checkName (no ADSI block found)" -ForegroundColor Yellow
            $script:skipped++
            continue
        }
        
        # Extract and clean the body
        $body = $match.Groups[1].Value
        $lines = $body -split "`n"
        $cleanedLines = @()
        
        foreach ($line in $lines) {
            # Remove leading indentation (8 or 4 spaces)
            if ($line -match '^        (.*)$') {
                $cleanedLines += $matches[1]
            } elseif ($line -match '^    (.*)$') {
                $cleanedLines += $matches[1]
            } else {
                $cleanedLines += $line
            }
        }
        
        $bodyText = ($cleanedLines | Where-Object { $_ -ne $null -and $_.Trim() -ne '' }) -join "`n"
        
        # Fix the FindAll pattern to use $results variable
        $bodyText = $bodyText -replace 
            '\$searcher\.FindAll\(\)\s*\|\s*ForEach-Object\s*\{',
            "`$results = `$searcher.FindAll()`n`$results | ForEach-Object {"
        
        # Extract metadata from combined file
        $headerMatch = [regex]::Match($combinedContent, '# Check:\s*(.+?)(?=\n|$)')
        $idMatch = [regex]::Match($combinedContent, '# ID:\s*(.+?)(?=\n|$)')
        $categoryMatch = [regex]::Match($combinedContent, '# Category:\s*(.+?)(?=\n|$)')
        $severityMatch = [regex]::Match($combinedContent, '# Severity:\s*(.+?)(?=\n|$)')
        
        $checkName_meta = if ($headerMatch.Success) { $headerMatch.Groups[1].Value.Trim() } else { $checkName }
        $checkId = if ($idMatch.Success) { $idMatch.Groups[1].Value.Trim() } else { $checkName }
        $category = if ($categoryMatch.Success) { $categoryMatch.Groups[1].Value.Trim() } else { 'General' }
        $severity = if ($severityMatch.Success) { $severityMatch.Groups[1].Value.Trim() } else { 'medium' }
        
        # Infer node type from LDAP filter
        $filterMatch = [regex]::Match($bodyText, "\`$searcher\.Filter\s*=\s*'(.+?)'")
        $ldapFilter = if ($filterMatch.Success) { $filterMatch.Groups[1].Value } else { '' }
        $catFolder = $checkDir.Parent.Name
        $nodeType = Get-NodeType $ldapFilter $catFolder
        
        # Build new content with BH block
        $bhBlock = Build-BhBlock $checkId $checkName_meta $severity $category $nodeType
        $newContent = @"
# Check: $checkName_meta
# Category: $category
# Severity: $severity
# ID: $checkId
# Requirements: None
# ============================================

$bodyText
$bhBlock
"@
        
        # Validate before writing
        $parseErrors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseInput(
            $newContent, [ref]$null, [ref]$parseErrors)
        
        if ($parseErrors.Count -gt 0) {
            Write-Host "  FAIL (validation): $checkName - $($parseErrors[0].Message)" -ForegroundColor Red
            $failList.Add("$checkId | $adsiPath | $($parseErrors[0].Message)")
            $script:failed++
        } else {
            Set-Content -Path $adsiPath -Value $newContent -Encoding UTF8 -Force
            Write-Host "  OK: $checkName ($nodeType)" -ForegroundColor Green
            $script:recovered++
            $script:bhAppended++
        }
    }
    catch {
        Write-Host "  ERROR: $checkName - $($_.Exception.Message)" -ForegroundColor Red
        $failList.Add("$checkName | $adsiPath | $($_.Exception.Message)")
        $script:failed++
    }
}

# ── Final parse sweep ─────────────────────────────────────────────────────────
Write-Host "`n=== Final Parse Sweep ===" -ForegroundColor Cyan
$sweepPass = 0
$sweepFail = 0
$sweepFailList = [System.Collections.Generic.List[string]]::new()

Get-ChildItem $SuiteRoot -Recurse -Filter 'adsi.ps1' | ForEach-Object {
    $c = Get-Content $_.FullName -Raw
    $e = $null
    $null = [System.Management.Automation.Language.Parser]::ParseInput($c, [ref]$null, [ref]$e)
    if ($e.Count -eq 0) {
        $sweepPass++
    } else {
        $sweepFail++
        $sweepFailList.Add("$($_.FullName) | $($e[0].Message)")
    }
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Recovered: $recovered" -ForegroundColor Green
Write-Host "BH Appended: $bhAppended" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor Red
Write-Host "Skipped: $skipped" -ForegroundColor Yellow
Write-Host ""
Write-Host "Parse PASS: $sweepPass" -ForegroundColor Green
Write-Host "Parse FAIL: $sweepFail" -ForegroundColor Red

if ($failList.Count -gt 0) {
    Write-Host "`n=== Processing Failures ===" -ForegroundColor Red
    $failList | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkRed }
}

if ($sweepFailList.Count -gt 0) {
    Write-Host "`n=== Parse Failures ===" -ForegroundColor Red
    $sweepFailList | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkRed }
    if ($sweepFailList.Count -gt 10) {
        Write-Host "  ... and $($sweepFailList.Count - 10) more" -ForegroundColor DarkRed
    }
}

if ($sweepFail -eq 0 -and $failed -eq 0) {
    Write-Host "`n✅ ALL FILES CLEAN — Ready for BloodHound ingest" -ForegroundColor Green
} else {
    Write-Host "`n❌ FAILURES REMAIN — Review errors above" -ForegroundColor Red
}
