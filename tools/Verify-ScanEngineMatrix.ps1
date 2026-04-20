#requires -Version 5.1
<#
.SYNOPSIS
    CLI verification: Invoke-ADSuiteScan + ADSuite-Run-Cmd for one LDAP check (plan: matrix-ldap).

.DESCRIPTION
    Writes under out/scan-engine-verify-<timestamp>/ per engine/mode. Inspect scan-results.json EngineUsed and Errors.
    Does not call the web API (use scan.meta.json from a web run + npm run test:scan-engine for API mapping).

.PARAMETER CheckId
    Catalog check id (default ACC-001).

.PARAMETER SkipCmdWrapper
    Skip engines\ADSuite-Run-Cmd.cmd (optional if cmd.exe issues).
#>
[CmdletBinding()]
param(
    [string]$CheckId = 'ACC-001',
    [switch]$SkipCmdWrapper
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$invoke = Join-Path $repoRoot 'Invoke-ADSuiteScan.ps1'
$cmdBat = Join-Path $repoRoot 'engines\ADSuite-Run-Cmd.cmd'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$baseOut = Join-Path $repoRoot "out\scan-engine-verify-$stamp"

if (-not (Test-Path -LiteralPath $invoke)) {
    throw "Invoke-ADSuiteScan.ps1 not found: $invoke"
}

$ldapEngines = @('Adsi', 'Rsat', 'Combined', 'Csharp')
$summary = [System.Collections.Generic.List[object]]::new()

foreach ($le in $ldapEngines) {
    $dir = Join-Path $baseOut "invoke-$le"
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $args = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $invoke,
        '-IncludeCheckId', $CheckId,
        '-OutputDirectory', $dir,
        '-LdapEngine', $le
    )
    $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $args -Wait -PassThru -NoNewWindow
    $row = [ordered]@{
        Mode       = "Invoke-ADSuiteScan"
        LdapEngine = $le
        ExitCode   = $p.ExitCode
        Results    = (Join-Path $dir 'scan-results.json')
    }
    $summary.Add([pscustomobject]$row) | Out-Null
}

if (-not $SkipCmdWrapper -and (Test-Path -LiteralPath $cmdBat)) {
    $checksPath = Join-Path $repoRoot 'checks.json'
    foreach ($mode in @('adsi', 'rsat', 'combined')) {
        $cArgs = @(
            $mode,
            '-CheckId', $CheckId,
            '-ChecksJsonPath', $checksPath
        )
        $p = Start-Process -FilePath $cmdBat -ArgumentList $cArgs -Wait -PassThru -NoNewWindow
        $summary.Add([pscustomobject]@{
                Mode       = 'ADSuite-Run-Cmd.cmd'
                LdapEngine = $mode
                ExitCode   = $p.ExitCode
                Results    = $null
            }) | Out-Null
    }
}

# C# runner locations (plan: csharp-prereq)
$publishExe = Join-Path $repoRoot 'engines\csharp\publish\ADSuite.LdapRunner.exe'
$binExe = Join-Path $repoRoot 'engines\csharp\ADSuite.LdapRunner\bin\Release\net8.0-windows\ADSuite.LdapRunner.exe'
$csNote = [ordered]@{
    PublishPath = $publishExe
    PublishExists = (Test-Path -LiteralPath $publishExe)
    BinReleasePath = $binExe
    BinReleaseExists = (Test-Path -LiteralPath $binExe)
}

Write-Host "CSharp runner:" -ForegroundColor Cyan
[pscustomobject]$csNote | Format-List

Write-Host "Summary (exit codes only; AD/LDAP errors are environment-specific):" -ForegroundColor Cyan
$summary | Format-Table -AutoSize

Write-Host "Output root: $baseOut" -ForegroundColor Green
