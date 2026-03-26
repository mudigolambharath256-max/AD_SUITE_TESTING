#requires -Version 5.1
<#
.SYNOPSIS
    Run all LDAP checks from a catalog and write JSON, CSV, and HTML report.

.PARAMETER ChecksJsonPath
    Path to checks catalog (checks.json or checks.generated.json).

.PARAMETER OutputDirectory
    Folder for this run. Default: .\out\scan-<timestamp>

.PARAMETER ServerName
    Optional DC host name.

.PARAMETER Category
    One or more category names to include (e.g. Access_Control).

.PARAMETER IncludeCheckId
    Only run these check ids.

.PARAMETER ExcludeCheckId
    Skip these check ids.

.PARAMETER StopOnFirstError
    Stop the scan when the first check returns an error (default: run all checks).

.PARAMETER FindingCapPerCheck
    Max findings counted per check toward score (default 10).

.PARAMETER ScoringNormalizer
    Divides raw score sum to produce global 0-100 score (default 5).

.PARAMETER ChecksOverridesPath
    Optional JSON file of partial check objects keyed by id (patches base catalog). If omitted and checks.overrides.json exists next to this script, it is loaded automatically.

.PARAMETER SkipCatalogValidation
    Skip structural validation (duplicate ids, required fields per engine). Not recommended for CI.

.EXAMPLE
    .\Invoke-ADSuiteScan.ps1 -ChecksJsonPath .\checks.json -OutputDirectory .\out\latest
#>
[CmdletBinding()]
param(
    [string]$ChecksJsonPath,

    [string]$ChecksOverridesPath,

    [string]$OutputDirectory,

    [string]$ServerName,

    [string[]]$Category,

    [string[]]$IncludeCheckId,

    [string[]]$ExcludeCheckId,

    [switch]$StopOnFirstError,

    [int]$FindingCapPerCheck = 10,

    [int]$ScoringNormalizer = 5,

    [switch]$SkipCatalogValidation
)

function Expand-ObjectsToUniformCsvRows {
    param([System.Collections.IEnumerable]$Objects)
    $list = @($Objects)
    if ($list.Count -eq 0) { return @() }
    $keys = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($o in $list) {
        foreach ($p in $o.PSObject.Properties) {
            [void]$keys.Add($p.Name)
        }
    }
    $sorted = @($keys | Sort-Object)
    $out = [System.Collections.Generic.List[object]]::new()
    foreach ($o in $list) {
        $h = [ordered]@{}
        foreach ($k in $sorted) {
            $val = $null
            foreach ($p in $o.PSObject.Properties) {
                if ([string]::Equals($p.Name, $k, [StringComparison]::OrdinalIgnoreCase)) {
                    $val = $p.Value
                    break
                }
            }
            $h[$k] = if ($null -ne $val) { $val } else { '' }
        }
        $out.Add([PSCustomObject]$h)
    }
    return $out
}

$ErrorActionPreference = 'Stop'

function Write-ScanErr([string]$Message) {
    [Console]::Error.WriteLine($Message)
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $ChecksJsonPath) {
    $ChecksJsonPath = Join-Path $scriptDir 'checks.json'
}

if (-not (Test-Path -LiteralPath $ChecksJsonPath)) {
    Write-ScanErr "Checks file not found: $ChecksJsonPath"
    exit 1
}

$modulePath = Join-Path $scriptDir 'Modules\ADSuite.Adsi.psm1'
Import-Module $modulePath -Force -ErrorAction Stop

$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $scriptDir "out\scan-$ts"
}
if (-not (Test-Path -LiteralPath $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

$defaultOv = Join-Path $scriptDir 'checks.overrides.json'
if (-not $ChecksOverridesPath -and (Test-Path -LiteralPath $defaultOv)) {
    $ChecksOverridesPath = $defaultOv
}

$doc = Import-ADSuiteCatalogJson -ChecksJsonPath $ChecksJsonPath -ChecksOverridesPath $ChecksOverridesPath

if (-not $SkipCatalogValidation) {
    $integrity = Test-ADSuiteCatalogIntegrity -Document $doc
    $warnArr = @($integrity.Warnings)
    $maxW = 30
    for ($i = 0; $i -lt [Math]::Min($maxW, $warnArr.Count); $i++) {
        Write-Host "Catalog warning: $($warnArr[$i])" -ForegroundColor DarkYellow
    }
    if ($warnArr.Count -gt $maxW) {
        Write-Host "Catalog warnings: $($warnArr.Count) total (showing first $maxW). Add severity/description via overlays or use checks.json." -ForegroundColor DarkYellow
    }
    if ($integrity.HasBlockingErrors) {
        foreach ($e in $integrity.Errors) {
            Write-ScanErr $e
        }
        exit 1
    }
}

$candidates = @($doc.checks | Where-Object {
        $e = if ($_.engine) { $_.engine.ToLowerInvariant() } else { 'ldap' }
        if ($e -eq 'inventory') { return $false }
        $e -in @('ldap', 'filesystem', 'registry')
    })

if ($Category -and $Category.Count -gt 0) {
    $set = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($c in $Category) { [void]$set.Add($c) }
    $candidates = @($candidates | Where-Object { $set.Contains([string]$_.category) })
}

if ($IncludeCheckId -and $IncludeCheckId.Count -gt 0) {
    $inc = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($x in $IncludeCheckId) { [void]$inc.Add($x) }
    $candidates = @($candidates | Where-Object { $inc.Contains([string]$_.id) })
}

if ($ExcludeCheckId -and $ExcludeCheckId.Count -gt 0) {
    $exc = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($x in $ExcludeCheckId) { [void]$exc.Add($x) }
    $candidates = @($candidates | Where-Object { -not $exc.Contains([string]$_.id) })
}

$seen = @{}
$checksToRun = [System.Collections.Generic.List[object]]::new()
foreach ($raw in $candidates) {
    $id = [string]$raw.id
    if ([string]::IsNullOrWhiteSpace($id)) { continue }
    if ($seen.ContainsKey($id)) {
        Write-ScanErr "Duplicate CheckId in catalog: $id"
        exit 1
    }
    $seen[$id] = $true
    $merged = Merge-ADSuiteCheckDefaults -Defaults $doc.defaults -Check $raw
    $checksToRun.Add($merged)
}

Write-Host "AD Suite scan: $($checksToRun.Count) check(s) (ldap/filesystem/registry). Output: $OutputDirectory" -ForegroundColor Cyan

try {
    $rootDse = Get-ADSuiteRootDse -ServerName $ServerName
} catch {
    Write-ScanErr $_.Exception.Message
    exit 1
}

$results = [System.Collections.Generic.List[object]]::new()
$totalFindings = 0
$checksWithFindings = 0
$checksWithErrors = 0

foreach ($chk in $checksToRun) {
    $eng = if ($chk.engine) { $chk.engine.ToLowerInvariant() } else { 'ldap' }
    $r = $null
    switch ($eng) {
        'ldap' {
            $r = Invoke-ADSuiteLdapCheck -Check $chk -RootDse $rootDse -ServerName $ServerName -SourcePathOverride $null
        }
        'filesystem' {
            $r = Invoke-ADSuiteFilesystemCheck -Check $chk -RootDse $rootDse -ServerName $ServerName -SourcePathOverride $null
        }
        'registry' {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $sw.Stop()
            $meta = Get-ADSuiteOptionalCheckMeta -Check $chk
            $r = [PSCustomObject]@{
                CheckId       = [string]$chk.id
                CheckName     = if ($chk.name) { [string]$chk.name } else { [string]$chk.id }
                Category      = if ($chk.category) { [string]$chk.category } else { 'Unknown' }
                Severity      = if ($chk.severity) { [string]$chk.severity } else { 'medium' }
                Description   = if ($chk.description) { [string]$chk.description } else { $null }
                FindingCount  = 0
                Result        = 'Error'
                DurationMs    = [int]$sw.ElapsedMilliseconds
                Error         = 'Registry engine not implemented yet.'
                ExitCode      = 1
                Findings      = [object[]]@()
                SourcePath    = $null
                Remediation   = $meta.Remediation
                References    = $meta.References
                ScoreWeight   = $meta.ScoreWeight
            }
        }
        default {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $sw.Stop()
            $meta = Get-ADSuiteOptionalCheckMeta -Check $chk
            $r = [PSCustomObject]@{
                CheckId       = [string]$chk.id
                CheckName     = if ($chk.name) { [string]$chk.name } else { [string]$chk.id }
                Category      = if ($chk.category) { [string]$chk.category } else { 'Unknown' }
                Severity      = 'medium'
                Description   = $null
                FindingCount  = 0
                Result        = 'Error'
                DurationMs    = [int]$sw.ElapsedMilliseconds
                Error         = "Unsupported engine '$eng'."
                ExitCode      = 1
                Findings      = [object[]]@()
                SourcePath    = $null
                Remediation   = $meta.Remediation
                References    = $meta.References
                ScoreWeight   = $meta.ScoreWeight
            }
        }
    }

    [void]$results.Add($r)

    if ($r.Error -or $r.Result -eq 'Error') {
        $checksWithErrors++
        if ($StopOnFirstError) { break }
    }
    if ($r.FindingCount -gt 0) {
        $checksWithFindings++
        $totalFindings += [int]$r.FindingCount
    }
}

$scoring = Add-ADSuiteScanScores -Results $results -FindingCapPerCheck $FindingCapPerCheck -Normalizer $ScoringNormalizer

$byCategory = @{}
foreach ($r in $results) {
    $cat = [string]$r.Category
    if (-not $byCategory.ContainsKey($cat)) {
        $byCategory[$cat] = @{ checks = 0; withFindings = 0; errors = 0 }
    }
    $byCategory[$cat].checks++
    if ($r.FindingCount -gt 0) { $byCategory[$cat].withFindings++ }
    if ($r.Error -or $r.Result -eq 'Error') { $byCategory[$cat].errors++ }
}

$scanMeta = @{}
if ($doc.meta) {
    foreach ($p in $doc.meta.PSObject.Properties) {
        $scanMeta[$p.Name] = $p.Value
    }
}
$scanMeta['scanTimeUtc'] = (Get-Date).ToUniversalTime().ToString('o')
$scanMeta['serverName'] = $ServerName
$scanMeta['defaultNamingContext'] = $rootDse.DefaultNamingContext
$scanMeta['checksJsonPath'] = (Resolve-Path -LiteralPath $ChecksJsonPath).Path
$scanMeta['checksOverridesPath'] = if ($ChecksOverridesPath) { (Resolve-Path -LiteralPath $ChecksOverridesPath).Path } else { $null }
$scanMeta['checksRun'] = $results.Count
$scanMeta['scoringNormalizer'] = $ScoringNormalizer
$scanMeta['findingCapPerCheck'] = $FindingCapPerCheck

$scanDoc = @{
    schemaVersion = 1
    meta          = $scanMeta
    aggregate     = @{
        checksRun          = $results.Count
        checksWithFindings = $checksWithFindings
        checksWithErrors   = $checksWithErrors
        totalFindings      = $totalFindings
        globalRaw          = $scoring.GlobalRaw
        globalScore        = $scoring.GlobalScore
        globalRiskBand     = $scoring.GlobalRiskBand
        scoreByCategory    = $scoring.ScoreByCategory
    }
    byCategory    = $byCategory
    results       = @($results)
}

$jsonPath = Join-Path $OutputDirectory 'scan-results.json'
($scanDoc | ConvertTo-Json -Depth 25 -Compress:$false) | Set-Content -LiteralPath $jsonPath -Encoding UTF8

# Flatten findings for CSV
$csvRows = [System.Collections.Generic.List[object]]::new()
$scanTime = (Get-Date).ToUniversalTime().ToString('o')
foreach ($r in $results) {
    if ($r.Findings -and @($r.Findings).Count -gt 0) {
        foreach ($row in $r.Findings) {
            $csvRows.Add($row)
        }
    } else {
        $csvRows.Add([PSCustomObject]@{
                ScanTimeUtc  = $scanTime
                CheckId      = $r.CheckId
                CheckName    = $r.CheckName
                Category     = $r.Category
                Result       = $r.Result
                FindingCount = $r.FindingCount
                Error        = $r.Error
            })
    }
}

$csvPath = Join-Path $OutputDirectory 'findings.csv'
$uniform = Expand-ObjectsToUniformCsvRows -Objects $csvRows
if ($uniform.Count -gt 0) {
    $uniform | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
} else {
    [System.IO.File]::WriteAllText($csvPath, "ScanTimeUtc,CheckId,CheckName,Category,Result,FindingCount,Error`n", [System.Text.UTF8Encoding]::new($true))
}

$htmlPath = Join-Path $OutputDirectory 'report.html'
Export-ADSuiteHtmlReport -ScanDocument $scanDoc -OutputPath $htmlPath -Title 'AD Suite Scan Report'

Write-Host "Wrote: $jsonPath" -ForegroundColor Green
Write-Host "Wrote: $csvPath" -ForegroundColor Green
Write-Host "Wrote: $htmlPath" -ForegroundColor Green

exit 0
