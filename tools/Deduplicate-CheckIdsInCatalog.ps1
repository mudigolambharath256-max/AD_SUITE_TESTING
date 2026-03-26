#requires -Version 5.1
<#
.SYNOPSIS
    Rename duplicate check ids in a catalog JSON (2nd occurrence becomes id-dup2, etc.).

.PARAMETER CatalogPath
    Path to JSON (e.g. checks.generated.json).

.PARAMETER Backup
    Write CatalogPath.bak before modifying.
#>
param(
    [Parameter(Mandatory)]
    [string]$CatalogPath,

    [switch]$Backup
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $CatalogPath)) {
    throw "Not found: $CatalogPath"
}

$jsonText = Get-Content -LiteralPath $CatalogPath -Raw -Encoding UTF8
$doc = $jsonText | ConvertFrom-Json
$list = [System.Collections.Generic.List[object]]::new()
$seen = @{}
$renamed = 0
foreach ($c in @($doc.checks)) {
    $id = [string]$c.id
    if ([string]::IsNullOrWhiteSpace($id)) {
        $list.Add($c)
        continue
    }
    if (-not $seen.ContainsKey($id)) {
        $seen[$id] = 0
    }
    $seen[$id]++
    if ($seen[$id] -gt 1) {
        $newId = "$id-dup$($seen[$id])"
        $c | Add-Member -NotePropertyName id -NotePropertyValue $newId -Force
        $renamed++
        Write-Host "Renamed duplicate '$id' -> '$newId'"
    }
    $list.Add($c)
}
$doc.checks = @($list)

if ($renamed -eq 0) {
    Write-Host 'No duplicate ids found.'
    exit 0
}

if ($Backup) {
    $bak = "$CatalogPath.bak"
    Copy-Item -LiteralPath $CatalogPath -Destination $bak -Force
    Write-Host "Backup: $bak"
}

$out = $doc | ConvertTo-Json -Depth 25 -Compress:$false
[System.IO.File]::WriteAllText($CatalogPath, $out, [System.Text.UTF8Encoding]::new($false))
Write-Host "Wrote $CatalogPath ($renamed renames)." -ForegroundColor Green
