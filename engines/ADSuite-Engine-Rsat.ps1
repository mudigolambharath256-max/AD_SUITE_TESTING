#requires -Version 5.1
<#
.SYNOPSIS
    Run a single catalog check using RSAT ActiveDirectory (Get-ADObject) when the check is RSAT-compatible.
    Falls back to ADSI (Invoke-ADSuiteLdapCheck) inside the module for advanced rule fields.

.DESCRIPTION
    Install RSAT: Settings -> Optional features -> RSAT: Active Directory Domain Services and Lightweight Directory Services Tools.
    Requires domain-joined machine or appropriate credentials for the target forest.

.EXAMPLE
    .\ADSuite-Engine-Rsat.ps1 -CheckId ACC-001 -ServerName dc01.contoso.com
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$CheckId,

    [string]$ChecksJsonPath,

    [string]$ChecksOverridesPath,

    [string]$ServerName,

    [string]$SourcePath,

    [switch]$PassThru,

    [switch]$Quiet,

    [switch]$FailOnFindings,

    [switch]$CompactOutput,

    [switch]$AdcsSkipACLChecks,

    [switch]$AdcsSkipNetworkProbes
)

$ErrorActionPreference = 'Continue'
$enginesDir = $PSScriptRoot
$repoRoot = Split-Path -Parent $enginesDir
if (-not $ChecksJsonPath) {
    $unified = Join-Path $repoRoot 'checks.unified.json'
    if (Test-Path -LiteralPath $unified) { $ChecksJsonPath = $unified }
    else { $ChecksJsonPath = Join-Path $repoRoot 'checks.json' }
}

$modulePath = Join-Path $repoRoot 'Modules\ADSuite.Adsi.psm1'
Import-Module $modulePath -Force -ErrorAction Stop

$defaultOv = Join-Path $repoRoot 'checks.overrides.json'
if (-not $ChecksOverridesPath -and (Test-Path -LiteralPath $defaultOv)) {
    $ChecksOverridesPath = $defaultOv
}

$doc = Import-ADSuiteCatalogJson -ChecksJsonPath $ChecksJsonPath -ChecksOverridesPath $ChecksOverridesPath
$checkMatches = @($doc.checks | Where-Object { $_.id -eq $CheckId })
if ($checkMatches.Count -ne 1) {
    [Console]::Error.WriteLine("Expected exactly one check with id '$CheckId'.")
    exit 1
}
$check = Merge-ADSuiteCheckDefaults -Defaults $doc.defaults -Check $checkMatches[0]

$paramSource = $null
if ($PSBoundParameters.ContainsKey('SourcePath') -and -not [string]::IsNullOrWhiteSpace($SourcePath)) {
    $paramSource = $SourcePath.Trim()
}

$rootDse = Get-ADSuiteRootDse -ServerName $ServerName
$engine = if ($check.engine) { $check.engine.ToLowerInvariant() } else { 'ldap' }

$result = $null
switch ($engine) {
    'ldap' {
        $result = Invoke-ADSuiteLdapCheckViaRsat -Check $check -RootDse $rootDse -ServerName $ServerName -SourcePathOverride $paramSource
    }
    'filesystem' {
        $result = Invoke-ADSuiteFilesystemCheck -Check $check -RootDse $rootDse -ServerName $ServerName -SourcePathOverride $paramSource
    }
    'adcs' {
        $result = Invoke-ADSuiteAdcsCheck -Check $check -RootDse $rootDse -ServerName $ServerName `
            -AdcsSkipACLChecks:$AdcsSkipACLChecks -AdcsSkipNetworkProbes:$AdcsSkipNetworkProbes
    }
    'acl' {
        $result = Invoke-ADSuiteAclCheck -Check $check -RootDse $rootDse -ServerName $ServerName -SourcePathOverride $paramSource
    }
    default {
        [Console]::Error.WriteLine("Engine '$engine' not supported in RSAT runner (use adsi.ps1 or Invoke-ADSuiteScan.ps1).")
        exit 2
    }
}

if ($result.Error) {
    [Console]::Error.WriteLine($result.Error)
    exit [int]$result.ExitCode
}

if (-not $Quiet) {
    $eng = if ($result.PSObject.Properties.Name -contains 'EngineUsed') { $result.EngineUsed } else { 'ADSI' }
    Write-Host "Check $($result.CheckId): $($result.CheckName)  [engine: $eng]" -ForegroundColor Cyan
    Write-Host "  FindingCount: $($result.FindingCount)  Result: $($result.Result)" -ForegroundColor $(if ($result.FindingCount -eq 0) { 'Green' } else { 'Yellow' })
}

$rowsOut = @($result.Findings)
if ($PassThru) {
    $rowsOut
} elseif ($rowsOut.Count -gt 0) {
    if ($CompactOutput) {
        $rowsOut | Select-Object -Property * -ExcludeProperty CheckId, CheckName, FindingCount, Result, SourcePath, Severity, Description | Format-Table -AutoSize
    } else {
        $rowsOut | Format-Table -AutoSize
    }
} elseif (-not $Quiet) {
    Write-Host 'No finding rows (Pass).' -ForegroundColor Green
}

if ($FailOnFindings -and $result.FindingCount -gt 0) { exit 3 }
exit 0
