#requires -Version 5.1
<#
.SYNOPSIS
    Promote Certificate_Services LDAP stubs from checks.generated.json into risk-style ldap checks (Configuration vs Domain searchBase, metadata).

.DESCRIPTION
    Skips CERT-002..005 and CERT-020..022 (overlap with ADCS-ESC1..ESC8 in checks.json).
    CERT-023 and CERT-024 use searchBase Domain; other promoted CERT-* use Configuration.

.PARAMETER RepoRoot
    AD_SUITE root (contains checks.generated.json).

.PARAMETER GeneratedPath
    Override path to generated catalog (default: RepoRoot\checks.generated.json).

.PARAMETER MetadataPath
    JSON map of CERT-* id -> severity, description, remediation, references[], optional scoreWeight.

.PARAMETER OutFragmentPath
    If set, writes promoted checks array as JSON to this path (no merge).

.PARAMETER MergeIntoChecksJson
    If set, inserts promoted checks after ADCS-ESC8 and before DC-003; bumps meta.packVersion / packDateUtc.

.PARAMETER PackVersion
    New pack version when merging (default 1.5.1).

.PARAMETER PackDateUtc
    ISO UTC timestamp for meta (default: now).
#>
[CmdletBinding()]
param(
    [string]$RepoRoot,

    [string]$GeneratedPath,

    [string]$MetadataPath,

    [string]$OutFragmentPath,

    [switch]$MergeIntoChecksJson,

    [string]$PackVersion = '1.5.1',

    [string]$PackDateUtc = ''
)

$ErrorActionPreference = 'Stop'

$toolsDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent $toolsDir }
if (-not $MetadataPath) { $MetadataPath = Join-Path $toolsDir 'CertificateServicesLdapMetadata.json' }

function ConvertTo-ADSuiteOutputPropertyMap {
    param([string[]]$PropertiesToLoad)
    $map = [ordered]@{}
    foreach ($ldapAttr in $PropertiesToLoad) {
        if ([string]::IsNullOrWhiteSpace($ldapAttr)) { continue }
        if ($ldapAttr.Contains('-')) {
            $parts = $ldapAttr -split '-'
            $key = ($parts | ForEach-Object {
                    if ($_.Length -eq 0) { '' }
                    else { [char]::ToUpper($_[0]) + $_.Substring(1) }
                }) -join ''
        }
        else {
            $key = [char]::ToUpper($ldapAttr[0]) + $ldapAttr.Substring(1)
        }
        $map[$key] = $ldapAttr
    }
    return [hashtable]$map
}

function Get-OptionalMetaString {
    param($Meta, [string]$PropertyName)
    $p = $Meta.PSObject.Properties[$PropertyName]
    if ($null -eq $p) { return $null }
    $v = $p.Value
    if ($null -eq $v) { return $null }
    return [string]$v
}

function ConvertTo-OrderedCheckObject {
    param(
        $Raw,
        $Meta,
        [string]$SearchBase,
        [string]$SourcePath
    )
    $nameOverride = Get-OptionalMetaString -Meta $Meta -PropertyName 'name'
    $filterOverride = Get-OptionalMetaString -Meta $Meta -PropertyName 'ldapFilter'
    $propsOverride = $null
    $pp = $Meta.PSObject.Properties['propertiesToLoad']
    if ($null -ne $pp -and $null -ne $pp.Value) {
        $propsOverride = @($pp.Value)
    }

    $finalName = if ($nameOverride) { $nameOverride } else { [string]$Raw.name }
    $finalFilter = if ($filterOverride) { $filterOverride } else { [string]$Raw.ldapFilter }
    $finalProps = if ($propsOverride) { $propsOverride } else { @($Raw.propertiesToLoad) }

    $outProps = ConvertTo-ADSuiteOutputPropertyMap -PropertiesToLoad $finalProps
    $refs = $Meta.references
    if ($null -eq $refs) { $refs = @() }
    elseif ($refs -is [string]) { $refs = @($refs) }
    else { $refs = @($refs) }
    if ($refs.Count -eq 0) { $refs = @('SpecterOps Certified Pre-Owned (AD CS)') }

    $obj = [ordered]@{
        id                 = [string]$Raw.id
        name               = $finalName
        category           = [string]$Raw.category
        engine             = 'ldap'
        searchBase         = $SearchBase
        searchScope        = if ($Raw.searchScope) { [string]$Raw.searchScope } else { 'Subtree' }
        ldapFilter         = $finalFilter
        propertiesToLoad   = $finalProps
        outputProperties   = $outProps
        sourcePath         = $SourcePath
        severity           = [string]$Meta.severity
        description        = [string]$Meta.description
        remediation        = [string]$Meta.remediation
        references         = $refs
    }
    $swProp = $Meta.PSObject.Properties['scoreWeight']
    if ($null -ne $swProp) {
        $obj['scoreWeight'] = [double]$swProp.Value
    }
    return [PSCustomObject]$obj
}

if (-not $GeneratedPath) {
    $GeneratedPath = Join-Path $RepoRoot 'checks.generated.json'
}
if (-not (Test-Path -LiteralPath $GeneratedPath)) {
    throw "Generated catalog not found: $GeneratedPath"
}
if (-not (Test-Path -LiteralPath $MetadataPath)) {
    throw "Metadata file not found: $MetadataPath"
}

$skipIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($s in @('CERT-002', 'CERT-003', 'CERT-004', 'CERT-005', 'CERT-020', 'CERT-021', 'CERT-022')) {
    [void]$skipIds.Add($s)
}

$domainOnlyIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($s in @('CERT-023', 'CERT-024')) {
    [void]$domainOnlyIds.Add($s)
}

$gen = Get-Content -LiteralPath $GeneratedPath -Raw -Encoding UTF8 | ConvertFrom-Json
$metaDoc = Get-Content -LiteralPath $MetadataPath -Raw -Encoding UTF8 | ConvertFrom-Json

$promoted = [System.Collections.Generic.List[object]]::new()
foreach ($c in $gen.checks) {
    if ($c.category -ne 'Certificate_Services') { continue }
    $id = [string]$c.id
    if ($id -notlike 'CERT-*') { continue }
    if ($skipIds.Contains($id)) { continue }

    $m = $metaDoc.psobject.Properties[$id].Value
    if (-not $m) {
        throw "Missing metadata for $id in CertificateServicesLdapMetadata.json"
    }

    $sb = if ($domainOnlyIds.Contains($id)) { 'Domain' } else { 'Configuration' }

    $folderFromSource = $null
    if ($c.sourcePath -match 'Certificate_Services\\([^\\]+)\\adsi\.ps1') {
        $folderFromSource = $Matches[1]
    }
    $rel = if ($folderFromSource) {
        "Certificate_Services/$folderFromSource/adsi.ps1"
    }
    else {
        "Certificate_Services/$id/adsi.ps1"
    }

    $promoted.Add((ConvertTo-OrderedCheckObject -Raw $c -Meta $m -SearchBase $sb -SourcePath $rel))
}

Write-Host "Promoted $($promoted.Count) Certificate_Services ldap checks (skipped $($skipIds.Count) ESC-overlap IDs)." -ForegroundColor Cyan

if ($OutFragmentPath) {
    $frag = @{'promoted' = @($promoted); 'count' = $promoted.Count }
    $frag | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $OutFragmentPath -Encoding UTF8
    Write-Host "Wrote fragment: $OutFragmentPath" -ForegroundColor Green
}

if ($MergeIntoChecksJson) {
    $checksJsonPath = Join-Path $RepoRoot 'checks.json'
    $doc = Get-Content -LiteralPath $checksJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json

    $before = [System.Collections.Generic.List[object]]::new()
    $after = [System.Collections.Generic.List[object]]::new()
    $pastInsert = $false
    foreach ($chk in $doc.checks) {
        if ($chk.id -eq 'DC-003') {
            $pastInsert = $true
        }
        if (-not $pastInsert) {
            if ($chk.id -match '^CERT-') { continue }
            $before.Add($chk)
        }
        else {
            $after.Add($chk)
        }
    }

    $merged = [System.Collections.Generic.List[object]]::new()
    foreach ($x in $before) { $merged.Add($x) }
    foreach ($x in $promoted) { $merged.Add($x) }
    foreach ($x in $after) { $merged.Add($x) }

    $doc.checks = @($merged.ToArray())
    $doc.meta.packVersion = $PackVersion
    if (-not $PackDateUtc) {
        $PackDateUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    }
    $doc.meta.packDateUtc = $PackDateUtc

    $json = $doc | ConvertTo-Json -Depth 30
    Set-Content -LiteralPath $checksJsonPath -Value $json -Encoding UTF8
    Write-Host "Merged into $checksJsonPath (packVersion=$PackVersion)." -ForegroundColor Green
}
