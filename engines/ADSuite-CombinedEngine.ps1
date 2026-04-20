#requires -Version 5.1
<#
.SYNOPSIS
    Enterprise runner: try RSAT, then ADSI (adsi.ps1), then optional C# LDAP binary.

.DESCRIPTION
    ADSUITE_ENGINE_ORDER (comma-separated): rsat, adsi, dotnet — default rsat,adsi,dotnet
    ADSUITE_SKIP_DOTNET=1 skips the C# runner.

    Publish C# once:
      dotnet publish .\engines\csharp\ADSuite.LdapRunner\ADSuite.LdapRunner.csproj -c Release -o .\engines\csharp\publish

.EXAMPLE
    .\ADSuite-CombinedEngine.ps1 -CheckId ACC-001 -ServerName dc01.contoso.com
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$CheckId,

    [string]$ChecksJsonPath,

    [string]$ServerName,

    [switch]$Quiet,

    [switch]$PassThru,

    [switch]$FailOnFindings
)

$ErrorActionPreference = 'Continue'
$enginesDir = $PSScriptRoot
$repoRoot = Split-Path -Parent $enginesDir

$orderRaw = $env:ADSUITE_ENGINE_ORDER
if ([string]::IsNullOrWhiteSpace($orderRaw)) { $orderRaw = 'rsat,adsi,dotnet' }
$order = @($orderRaw.Split(',') | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ })

$adsiScript = Join-Path $repoRoot 'adsi.ps1'
$rsatScript = Join-Path $enginesDir 'ADSuite-Engine-Rsat.ps1'
$dotnetExe = Join-Path (Join-Path $enginesDir 'csharp\publish') 'ADSuite.LdapRunner.exe'
if (-not (Test-Path -LiteralPath $dotnetExe)) {
    $dotnetExe = Join-Path (Join-Path $enginesDir 'csharp\ADSuite.LdapRunner\bin\Release\net8.0-windows') 'ADSuite.LdapRunner.exe'
}

$shellExe = (Get-Process -Id $PID -ErrorAction SilentlyContinue).Path
if (-not $shellExe -or -not (Test-Path -LiteralPath $shellExe)) {
    $shellExe = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
}

if (-not $ChecksJsonPath) {
    $unified = Join-Path $repoRoot 'checks.unified.json'
    if (Test-Path -LiteralPath $unified) { $ChecksJsonPath = $unified }
    else { $ChecksJsonPath = Join-Path $repoRoot 'checks.json' }
}

$lastErr = ''
foreach ($eng in $order) {
    if ($eng -eq 'dotnet' -and $env:ADSUITE_SKIP_DOTNET -eq '1') { continue }

    if ($eng -eq 'rsat') {
        if (-not (Test-Path -LiteralPath $rsatScript)) { continue }
        if (-not $Quiet) { Write-Host "=== Trying engine: RSAT ===" -ForegroundColor DarkCyan }
        $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $rsatScript, '-CheckId', $CheckId, '-ChecksJsonPath', $ChecksJsonPath)
        if ($ServerName) { $argList += @('-ServerName', $ServerName) }
        if ($Quiet) { $argList += '-Quiet' }
        if ($PassThru) { $argList += '-PassThru' }
        if ($FailOnFindings) { $argList += '-FailOnFindings' }
        $proc = Start-Process -FilePath $shellExe -ArgumentList $argList -Wait -PassThru -NoNewWindow
        $code = $proc.ExitCode
        if ($code -eq 0 -or ($code -eq 3 -and $FailOnFindings)) {
            if (-not $Quiet) { Write-Host "RSAT engine finished (exit $code)." -ForegroundColor Green }
            exit $code
        }
        $lastErr = "RSAT exit $code"
        continue
    }

    if ($eng -eq 'adsi') {
        if (-not (Test-Path -LiteralPath $adsiScript)) { continue }
        if (-not $Quiet) { Write-Host "=== Trying engine: ADSI (adsi.ps1) ===" -ForegroundColor DarkCyan }
        $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $adsiScript, '-CheckId', $CheckId, '-ChecksJsonPath', $ChecksJsonPath)
        if ($ServerName) { $argList += @('-ServerName', $ServerName) }
        if ($Quiet) { $argList += '-Quiet' }
        if ($PassThru) { $argList += '-PassThru' }
        if ($FailOnFindings) { $argList += '-FailOnFindings' }
        $proc = Start-Process -FilePath $shellExe -ArgumentList $argList -Wait -PassThru -NoNewWindow
        $code = $proc.ExitCode
        if ($code -eq 0 -or ($code -eq 3 -and $FailOnFindings)) {
            if (-not $Quiet) { Write-Host "ADSI engine finished (exit $code)." -ForegroundColor Green }
            exit $code
        }
        $lastErr = "ADSI exit $code"
        continue
    }

    if ($eng -eq 'dotnet') {
        if (-not (Test-Path -LiteralPath $dotnetExe)) {
            if (-not $Quiet) { Write-Host "=== Skipping dotnet: build/publish ADSuite.LdapRunner to engines\csharp\publish ===" -ForegroundColor DarkYellow }
            continue
        }
        if (-not $Quiet) { Write-Host "=== Trying engine: C# ===" -ForegroundColor DarkCyan }
        $argsD = @($ChecksJsonPath, $CheckId)
        if ($ServerName) { $argsD += $ServerName }
        $p = Start-Process -FilePath $dotnetExe -ArgumentList $argsD -NoNewWindow -Wait -PassThru
        $code = $p.ExitCode
        if ($code -eq 0) {
            if (-not $Quiet) { Write-Host "C# engine finished (exit 0)." -ForegroundColor Green }
            exit 0
        }
        $lastErr = "dotnet exit $code"
        continue
    }
}

Write-Host "All engines failed. Last: $lastErr" -ForegroundColor Red
exit 1
