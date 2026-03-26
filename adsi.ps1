#requires -Version 5.1
<#
.SYNOPSIS
    Run a single AD Suite LDAP check defined in checks.json (ADSI / DirectorySearcher).

.PARAMETER CheckId
    Check identifier, e.g. ACC-001, KRB-002, DC-003.

.PARAMETER ChecksJsonPath
    Path to checks.json. Defaults to checks.json next to this script.

.PARAMETER ServerName
    Optional DC host name for LDAP binding (RootDSE and search roots).

.PARAMETER SourcePath
    Optional path to the original script or definition (e.g. legacy adsi.ps1). Overrides sourcePath from checks.json when set.

.EXAMPLE
    .\adsi.ps1 -CheckId ACC-001
.EXAMPLE
    .\adsi.ps1 -CheckId ACC-001 -SourcePath 'C:\Repo\Access_Control\ACC-001\adsi.ps1'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$CheckId,

    [string]$ChecksJsonPath,

    [string]$ServerName,

    [string]$SourcePath
)

$ErrorActionPreference = 'Continue'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $ChecksJsonPath) {
    $ChecksJsonPath = Join-Path $scriptDir 'checks.json'
}

if (-not (Test-Path -LiteralPath $ChecksJsonPath)) {
    Write-Error "Checks file not found: $ChecksJsonPath"
    exit 1
}

$modulePath = Join-Path $scriptDir 'Modules\ADSuite.Adsi.psm1'
if (-not (Test-Path -LiteralPath $modulePath)) {
    Write-Error "Module not found: $modulePath"
    exit 1
}
Import-Module $modulePath -Force -ErrorAction Stop

function ConvertTo-HashtableOutputMap {
    param($OutputProperties)
    if ($null -eq $OutputProperties) { return @{} }
    if ($OutputProperties -is [hashtable]) { return $OutputProperties }
    $h = @{}
    foreach ($p in $OutputProperties.PSObject.Properties) {
        $h[$p.Name] = [string]$p.Value
    }
    return $h
}

function Merge-CheckDefaults {
    param($Defaults, $Check)
    $merged = @{}
    foreach ($p in $Check.PSObject.Properties) {
        $merged[$p.Name] = $p.Value
    }
    if ($Defaults) {
        foreach ($p in $Defaults.PSObject.Properties) {
            if (-not $merged.ContainsKey($p.Name)) {
                $merged[$p.Name] = $p.Value
            }
        }
    }
    [PSCustomObject]$merged
}

function Get-OutputPropertyMap {
    param($Check)
    $map = ConvertTo-HashtableOutputMap -OutputProperties $Check.outputProperties
    if ($map.Count -gt 0) { return $map }
    $h = @{}
    if ($Check.propertiesToLoad) {
        foreach ($p in $Check.propertiesToLoad) {
            if ($p) { $h[$p] = $p }
        }
    }
    return $h
}

try {
    $jsonText = Get-Content -LiteralPath $ChecksJsonPath -Raw -Encoding UTF8
    $doc = $jsonText | ConvertFrom-Json
} catch {
    Write-Error "Failed to read checks.json: $_"
    exit 1
}

$check = $doc.checks | Where-Object { $_.id -eq $CheckId }
if (-not $check) {
    Write-Error "Unknown CheckId: $CheckId"
    exit 1
}

$check = Merge-CheckDefaults -Defaults $doc.defaults -Check $check

$resolvedSourcePath = $null
if ($PSBoundParameters.ContainsKey('SourcePath') -and -not [string]::IsNullOrWhiteSpace($SourcePath)) {
    $resolvedSourcePath = $SourcePath.Trim()
} elseif ($check.PSObject.Properties.Name -contains 'sourcePath' -and -not [string]::IsNullOrWhiteSpace([string]$check.sourcePath)) {
    $resolvedSourcePath = [string]$check.sourcePath
}

$engine = if ($check.engine) { $check.engine.ToLowerInvariant() } else { 'ldap' }
if ($engine -ne 'ldap') {
    Write-Error "Check '$CheckId' uses engine '$engine', not ldap. Use the engine-specific runner for this check."
    exit 2
}

try {
    $rootDse = Get-ADSuiteRootDse -ServerName $ServerName
} catch {
    Write-Error $_
    exit 1
}

$searchBaseDn = $null
if ($check.PSObject.Properties.Name -contains 'searchBaseDn') {
    $searchBaseDn = $check.searchBaseDn
}

try {
    $searchRoot = Resolve-ADSuiteSearchRoot -SearchBase $check.searchBase -SearchBaseDn $searchBaseDn -RootDse $rootDse -ServerName $ServerName
} catch {
    Write-Error $_
    exit 1
}

$scope = if ($check.searchScope) { $check.searchScope } else { 'Subtree' }
$pageSize = [int]($check.pageSize)
if ($pageSize -lt 1) { $pageSize = 1000 }

$propsToLoad = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
if ($check.propertiesToLoad) {
    foreach ($p in $check.propertiesToLoad) {
        if ($p) { [void]$propsToLoad.Add($p) }
    }
}
[void]$propsToLoad.Add('distinguishedName')

$ldapFilter = $check.ldapFilter
if (-not $ldapFilter) {
    Write-Error "Check '$CheckId' has no ldapFilter."
    exit 1
}

try {
    $results = Invoke-ADSuiteLdapQuery -LdapFilter $ldapFilter -SearchRoot $searchRoot -SearchScope $scope -PropertiesToLoad @($propsToLoad) -PageSize $pageSize
} catch {
    Write-Error "LDAP query failed: $_"
    exit 1
}

$mustInc = 0
$mustExc = 0
if ($null -ne $check.userAccountControlMustInclude) { $mustInc = [int]$check.userAccountControlMustInclude }
if ($null -ne $check.userAccountControlMustExclude) { $mustExc = [int]$check.userAccountControlMustExclude }

$filtered = [System.Collections.Generic.List[object]]::new()
foreach ($sr in $results) {
    if ($mustInc -ne 0 -or $mustExc -ne 0) {
        $uacVal = Get-AdsProperty -Properties $sr.Properties -Name 'userAccountControl'
        if (-not (Test-UserAccountControlMask -UserAccountControlValue $uacVal -MustInclude $mustInc -MustExclude $mustExc)) {
            continue
        }
    }
    $filtered.Add($sr)
}

$outputMap = Get-OutputPropertyMap -Check $check
if ($outputMap.Count -eq 0) {
    foreach ($p in $propsToLoad) {
        $outputMap[$p] = $p
    }
}

Write-Host "Check $($check.id): $($check.name) - Found $($filtered.Count) object(s)" -ForegroundColor Cyan
if ($resolvedSourcePath) {
    Write-Host "SourcePath: $resolvedSourcePath" -ForegroundColor DarkGray
}

$rows = foreach ($sr in $filtered) {
    $props = $sr.Properties
    $row = [ordered]@{
        CheckId   = $check.id
        CheckName = $check.name
    }
    if ($resolvedSourcePath) {
        $row['SourcePath'] = $resolvedSourcePath
    }
    foreach ($entry in $outputMap.GetEnumerator()) {
        $colName = $entry.Key
        $attrName = $entry.Value
        $val = Get-AdsProperty -Properties $props -Name $attrName
        if ($null -eq $val) { $val = 'N/A' }
        $row[$colName] = $val
    }
    [PSCustomObject]$row
}

$rowsOut = @($rows)
if ($rowsOut.Count -gt 0) {
    $rowsOut | Format-Table -AutoSize
} else {
    Write-Host 'No findings' -ForegroundColor Gray
}

exit 0
