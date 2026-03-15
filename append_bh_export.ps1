# ============================================================================
# append_bh_export.ps1
# Usage: .\append_bh_export.ps1 -SuiteRoot "C:\Users\acer\Downloads\AD_suiteXXX"
# ============================================================================
param(
    [Parameter(Mandatory=$true)]
    [string]$SuiteRoot
)

$ErrorActionPreference = 'Stop'
$pass = 0; $fail = 0; $skip = 0
$failList = [System.Collections.Generic.List[string]]::new()

# -- Helpers ------------------------------------------------------------------
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

function Build-BhBlock([string]$checkId, [string]$checkName, [string]$severity,
                        [string]$category, [string]$nodeType) {
    # Escape single quotes in checkName for PS single-quoted string
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

# -- Main loop -----------------------------------------------------------------
$allAdsi = Get-ChildItem $SuiteRoot -Recurse -Filter 'adsi.ps1'
Write-Host "Processing $($allAdsi.Count) adsi.ps1 files..." -ForegroundColor Cyan

foreach ($file in $allAdsi) {
    $path    = $file.FullName
    $content = Get-Content $path -Raw

    # -- Sanity check --------------------------------------------------------------
    if ($content -notmatch '\[ADSISearcher\]') {
        Write-Host "  SKIP (no searcher - still corrupted?): $path" -ForegroundColor Yellow
        $skip++; continue
    }
    if ($content -match '# BLOODHOUND EXPORT') {
        Write-Host "  SKIP (BH block already present): $($file.Name) in $($file.Directory.Name)" -ForegroundColor DarkGray
        $skip++; continue
    }
    if ($content -match '\$results = \$searcher\.FindAll\(\)') {
        Write-Host "  SKIP (already has results var): $($file.Name)" -ForegroundColor DarkGray
        $skip++; continue
    }

    # -- Read header metadata ------------------------------------------------------
    $checkId   = if ($content -match '# ID: (.+)')       { $matches[1].Trim() } else { 'UNKNOWN' }
    $checkName = if ($content -match '# Check: (.+)')    { $matches[1].Trim() } else { $checkId }
    $severity  = if ($content -match '# Severity: (.+)') { $matches[1].Trim() } else { 'high' }
    $category  = if ($content -match '# Category: (.+)') { $matches[1].Trim() -replace ' ','_' } else { 'Unknown' }

    # -- Infer node type -----------------------------------------------------------
    $filterMatch = [regex]::Match($content, "\[ADSISearcher\]'(.+?)'")
    $ldapFilter  = if ($filterMatch.Success) { $filterMatch.Groups[1].Value } else { '' }
    $catFolder   = $file.Directory.Parent.Name
    $nodeType    = Get-NodeType $ldapFilter $catFolder

    # -- Change 1: store FindAll result in $results --------------------------------
    $oldFindAll = '$searcher.FindAll() | ForEach-Object {'
    $newFindAll = '$results = $searcher.FindAll()' + "`n" + '$results | ForEach-Object {'

    if ($content -notmatch [regex]::Escape($oldFindAll)) {
        Write-Host "  WARN (FindAll pattern not found): $checkId" -ForegroundColor Yellow
        $skip++; continue
    }
    $modified = $content -replace [regex]::Escape($oldFindAll), $newFindAll

    # -- Change 2: append BH export block ------------------------------------------
    $bhBlock  = Build-BhBlock $checkId $checkName $severity $category $nodeType
    $modified = $modified.TrimEnd() + "`n" + $bhBlock

    # -- Validate before writing ---------------------------------------------------
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseInput(
        $modified, [ref]$null, [ref]$parseErrors)

    if ($parseErrors.Count -gt 0) {
        Write-Host "  FAIL (parse error after edit): $checkId - $($parseErrors[0].Message)" -ForegroundColor Red
        $failList.Add("$checkId - $path - $($parseErrors[0].Message)")
        $fail++; continue
    }

    # All good - write
    Set-Content -Path $path -Value $modified -Encoding UTF8
    Write-Host "  OK: $checkId ($nodeType)" -ForegroundColor Green
    $pass++
}

# -- Final parse sweep ---------------------------------------------------------
Write-Host "`n=== Final Parse Sweep ===" -ForegroundColor Cyan
$sweepPass = 0; $sweepFail = 0
Get-ChildItem $SuiteRoot -Recurse -Filter 'adsi.ps1' | ForEach-Object {
    $c = Get-Content $_.FullName -Raw
    $e = $null
    $null = [System.Management.Automation.Language.Parser]::ParseInput($c, [ref]$null, [ref]$e)
    if ($e.Count -eq 0) { $sweepPass++ }
    else {
        $sweepFail++
        Write-Host "  STILL BROKEN: $($_.FullName)" -ForegroundColor Red
        Write-Host "    $($e[0].Message)" -ForegroundColor DarkRed
    }
}

# -- Report --------------------------------------------------------------------
Write-Host "`n=== RESULTS ===" -ForegroundColor Cyan
Write-Host "  Modified : $pass"   -ForegroundColor Green
Write-Host "  Failed   : $fail"   -ForegroundColor Red
Write-Host "  Skipped  : $skip"   -ForegroundColor Yellow
Write-Host "  Parse PASS: $sweepPass" -ForegroundColor Green
Write-Host "  Parse FAIL: $sweepFail" -ForegroundColor Red

if ($failList.Count -gt 0) {
    Write-Host "`n=== FAILURES ===" -ForegroundColor Red
    $failList | ForEach-Object { Write-Host "  $_" }
}

if ($sweepFail -eq 0 -and $fail -eq 0) {
    Write-Host "`n✅ ALL FILES CLEAN - Ready for BloodHound ingest" -ForegroundColor Green
} else {
    Write-Host "`n❌ FAILURES REMAIN - Do not run BloodHound ingest yet" -ForegroundColor Red
}
