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

.PARAMETER PassThru
    Emit finding rows as objects to the pipeline instead of formatting with Format-Table (use for automation; avoids format noise in files).

.PARAMETER Quiet
    Suppress host status lines (still writes errors to stderr when failing).

.PARAMETER FailOnFindings
    Exit with code 3 when FindingCount is greater than zero (for automation / CI). Successful pass (no findings) exits 0.

.PARAMETER CompactOutput
    Show only AD object properties in output, exclude metadata columns for cleaner display.

.PARAMETER ChecksOverridesPath
    Optional patches file (see checks.overrides.json). If omitted and checks.overrides.json exists next to this script, it is loaded.

.EXAMPLE
    .\adsi.ps1 -CheckId ACC-001 -CompactOutput
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

function Write-AdsiStderr {
    param([string]$Message)
    [Console]::Error.WriteLine($Message)
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $ChecksJsonPath) {
    $ChecksJsonPath = Join-Path $scriptDir 'checks.json'
}

if (-not (Test-Path -LiteralPath $ChecksJsonPath)) {
    Write-AdsiStderr "Checks file not found: $ChecksJsonPath"
    exit 1
}

$modulePath = Join-Path $scriptDir 'Modules\ADSuite.Adsi.psm1'
if (-not (Test-Path -LiteralPath $modulePath)) {
    Write-AdsiStderr "Module not found: $modulePath"
    exit 1
}
Import-Module $modulePath -Force -ErrorAction Stop

$defaultOv = Join-Path $scriptDir 'checks.overrides.json'
if (-not $ChecksOverridesPath -and (Test-Path -LiteralPath $defaultOv)) {
    $ChecksOverridesPath = $defaultOv
}

try {
    $doc = Import-ADSuiteCatalogJson -ChecksJsonPath $ChecksJsonPath -ChecksOverridesPath $ChecksOverridesPath
} catch {
    Write-AdsiStderr "Failed to read catalog: $_"
    exit 1
}

$checkMatches = @($doc.checks | Where-Object { $_.id -eq $CheckId })
if ($checkMatches.Count -eq 0) {
    Write-AdsiStderr "Unknown CheckId: $CheckId"
    exit 1
}
if ($checkMatches.Count -gt 1) {
    Write-AdsiStderr "Duplicate CheckId '$CheckId' in JSON ($($checkMatches.Count) entries); keep a single definition."
    exit 1
}

$check = Merge-ADSuiteCheckDefaults -Defaults $doc.defaults -Check $checkMatches[0]

$paramSource = $null
if ($PSBoundParameters.ContainsKey('SourcePath') -and -not [string]::IsNullOrWhiteSpace($SourcePath)) {
    $paramSource = $SourcePath.Trim()
}

try {
    $rootDse = Get-ADSuiteRootDse -ServerName $ServerName
} catch {
    Write-AdsiStderr $_.Exception.Message
    exit 1
}

$engine = if ($check.engine) { $check.engine.ToLowerInvariant() } else { 'ldap' }
if ($engine -eq 'inventory') {
    Write-AdsiStderr "Check '$CheckId' uses engine 'inventory' (documentation/inventory only; run with a misconfiguration rule or use adsi.ps1 after changing engine to ldap)."
    exit 2
}

$result = $null
switch ($engine) {
    'ldap' {
        $result = Invoke-ADSuiteLdapCheck -Check $check -RootDse $rootDse -ServerName $ServerName -SourcePathOverride $paramSource
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
    'registry' {
        Write-AdsiStderr "Check '$CheckId' uses engine 'registry' (not implemented in adsi.ps1 yet)."
        exit 2
    }
    default {
        Write-AdsiStderr "Unsupported engine '$engine' for check '$CheckId'."
        exit 2
    }
}

if ($result.Error) {
    Write-AdsiStderr $result.Error
    exit [int]$result.ExitCode
}

$findingCount = $result.FindingCount
$resultWord = $result.Result

if (-not $Quiet) {
    Write-Host "Check $($result.CheckId): $($result.CheckName)" -ForegroundColor Cyan
    Write-Host "  FindingCount: $findingCount  Result: $resultWord  (0 findings = Pass for risk checks)" -ForegroundColor $(if ($findingCount -eq 0) { 'Green' } else { 'Yellow' })
    if ($result.SourcePath) {
        Write-Host "  SourcePath: $($result.SourcePath)" -ForegroundColor DarkGray
    }
    if ($result.PSObject.Properties.Name -contains 'ScanNote' -and $result.ScanNote) {
        Write-Host "  Note: $($result.ScanNote)" -ForegroundColor DarkYellow
    }
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

if ($FailOnFindings -and $findingCount -gt 0) {
    exit 3
}
exit 0
