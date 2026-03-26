#requires -Version 5.1
<#
.SYNOPSIS
    Walk a legacy per-check folder tree (each containing adsi.ps1) and emit a JSON stub catalog
    for AD Suite (filters, search base hints, properties to load).

.PARAMETER LegacyRoot
    Root folder containing category subfolders with CHECK-ID_* / adsi.ps1 (e.g. AD_Security_Scripts_2026-02-05).

.PARAMETER OutputPath
    Where to write checks.generated.json (defaults to parent of tools: ..\checks.generated.json).

.NOTES
    Heuristic parsing: review and fix multi-line filters, non-LDAP checks, and Custom search bases manually.
    Every exported check uses engine inventory by default (unreviewed). Promote rules via checks.json or checks.overrides.json before treating them as production risk scans.
#>
[CmdletBinding()]
param(
    [string]$LegacyRoot = 'c:\Users\acer\Music\AD_Security_Scripts_2026-02-05',

    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $OutputPath) {
    $OutputPath = Join-Path (Split-Path -Parent $toolsDir) 'checks.generated.json'
}

if (-not (Test-Path -LiteralPath $LegacyRoot)) {
    throw "LegacyRoot not found: $LegacyRoot"
}

function Get-LdapFilterFromContent([string]$Content) {
    $c = $Content -replace "`r`n", "`n"
    $q = [char]39
    # Build patterns so \$ is a real regex escape for literal $ (PowerShell quoting makes this error-prone otherwise)
    $patAds = [char]92 + [char]91 + 'ADSISearcher' + [char]92 + [char]93 + '\s*' + $q + '([^' + $q + ']+)' + $q
    $patFilter = [char]92 + '$searcher\.Filter\s*=\s*' + $q + '([^' + $q + ']+)' + $q
    $patFilterDq = [char]92 + '$searcher\.Filter\s*=\s*"([^"]+)"'

    $m = [regex]::Match($c, $patAds)
    if ($m.Success) { return $m.Groups[1].Value.Trim() }

    $m = [regex]::Match($c, $patFilter)
    if ($m.Success) { return $m.Groups[1].Value.Trim() }

    $m = [regex]::Match($c, $patFilterDq)
    if ($m.Success) { return $m.Groups[1].Value.Trim() }

    return $null
}

function Get-SearchBaseKindFromContent([string]$Content) {
    $c = $Content
    if ($c -match 'SearchRoot\s*=\s*\[ADSI\]\([''"]LDAP://CN=Schema,') { return 'SchemaContainer' }
    if ($c -match 'SearchRoot\s*=\s*\[ADSI\]\([''"]LDAP://\$schemaNamingContext') { return 'Schema' }
    if ($c -match 'SearchRoot\s*=\s*\[ADSI\]\([''"]LDAP://\$configNC') { return 'Configuration' }
    if ($c -match 'SearchRoot\s*=\s*\[ADSI\]\([''"]LDAP://\$configurationNamingContext') { return 'Configuration' }
    if ($c -match 'SearchRoot\s*=\s*\[ADSI\]\([''"]LDAP://\$domainNC') { return 'Domain' }
    if ($c -match 'SearchRoot\s*=') { return 'Domain' }
    if ($c -match '\[ADSISearcher\]') { return 'Domain' }
    return 'Domain'
}

function Get-PropertiesToLoadFromContent([string]$Content) {
    $m = [regex]::Match($Content, '@\(\s*((?:''[^'']*''\s*,?\s*)+)\)', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $m.Success) { return @() }
    $inner = $m.Groups[1].Value
    $names = [regex]::Matches($inner, '''([^'']+)''') | ForEach-Object { $_.Groups[1].Value }
    return @($names)
}

function Get-CheckIdFromFolderName([string]$FolderName) {
    if ($FolderName -match '^([A-Za-z][A-Za-z0-9]*-[0-9]+)_') {
        return $Matches[1]
    }
    if ($FolderName -match '^([A-Za-z][A-Za-z0-9]*-[0-9]+)$') {
        return $Matches[1]
    }
    return $null
}

function Get-DefaultEngineFromLegacyFolder {
    <#
    Legacy export stubs are unreviewed: default inventory until promoted to risk (checks.json / overrides).
    #>
    param(
        [string]$FolderName,
        [string]$LdapFilter
    )
    return 'inventory'
}

function Get-DisplayNameFromFolderName([string]$FolderName, [string]$CheckId) {
    if (-not $CheckId) { return $FolderName }
    $rest = $FolderName -replace [regex]::Escape($CheckId), '' -replace '^_+', ''
    if ($rest) {
        return ($rest -replace '_', ' ').Trim()
    }
    return $FolderName
}

$files = Get-ChildItem -LiteralPath $LegacyRoot -Recurse -Filter 'adsi.ps1' -File -ErrorAction Stop
$checks = [System.Collections.Generic.List[object]]::new()
$stats = @{ Parsed = 0; MissingFilter = 0 }

foreach ($file in $files) {
    $folderName = $file.Directory.Name
    $checkId = Get-CheckIdFromFolderName -FolderName $folderName
    if (-not $checkId) {
        continue
    }

    $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
    $filter = Get-LdapFilterFromContent -Content $content
    $searchBase = Get-SearchBaseKindFromContent -Content $content
    $props = Get-PropertiesToLoadFromContent -Content $content

    if ($filter) { $stats.Parsed++ } else { $stats.MissingFilter++ }

    $rel = $file.FullName.Substring($LegacyRoot.TrimEnd('\').Length).TrimStart('\')
    $category = 'Unknown'
    $parts = $rel -split '\\'
    if ($parts.Length -ge 2) {
        $category = $parts[0]
    }

    $engineDefault = Get-DefaultEngineFromLegacyFolder -FolderName $folderName -LdapFilter $filter

    $entry = [ordered]@{
        id            = $checkId
        name          = (Get-DisplayNameFromFolderName -FolderName $folderName -CheckId $checkId)
        category      = $category
        engine        = $engineDefault
        searchBase    = $searchBase
        searchScope   = 'Subtree'
        ldapFilter    = $filter
        propertiesToLoad = @($props)
        sourcePath    = $file.FullName
    }
    $checks.Add([PSCustomObject]$entry)
}

$doc = [ordered]@{
    schemaVersion = 1
    defaults      = @{
        pageSize    = 1000
        engine      = 'inventory'
        searchScope = 'Subtree'
    }
    checks        = @($checks)
    meta          = @{
        generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
        legacyRoot   = $LegacyRoot
        totalFiles   = $files.Count
        stubCount    = $checks.Count
        parsedFilterCount = $stats.Parsed
        missingFilterCount = $stats.MissingFilter
    }
}

$json = $doc | ConvertTo-Json -Depth 12
# Unescape common LDAP filter characters for better readability
$json = $json -replace '\\u0026', '&'
$json = $json -replace '\\u003c', '<'
$json = $json -replace '\\u003e', '>'
$json = $json -replace '\\u003d', '='
[System.IO.File]::WriteAllText($OutputPath, $json, [System.Text.UTF8Encoding]::new($false))

Write-Host "Wrote $($checks.Count) check stubs to $OutputPath" -ForegroundColor Green
Write-Host "Filters parsed: $($stats.Parsed); missing filter: $($stats.MissingFilter) (review manually)" -ForegroundColor Cyan
