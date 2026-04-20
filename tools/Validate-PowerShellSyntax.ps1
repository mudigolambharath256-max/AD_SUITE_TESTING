# One-off syntax check for engine-related scripts (AST parse only).
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path (Join-Path $root 'Invoke-ADSuiteScan.ps1'))) {
    throw "Repo root not found (expected Invoke-ADSuiteScan.ps1 under $root)"
}
$files = @(
    'Invoke-ADSuiteScan.ps1',
    'adsi.ps1',
    'engines\ADSuite-Engine-Rsat.ps1',
    'engines\ADSuite-CombinedEngine.ps1',
    'Modules\ADSuite.Adsi.psm1'
)
$failed = 0
foreach ($rel in $files) {
    $p = Join-Path $root $rel
    if (-not (Test-Path $p)) {
        Write-Host "MISSING $rel"
        $failed++
        continue
    }
    $tok = $null
    $errs = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$tok, [ref]$errs)
    if ($errs.Count) {
        Write-Host "FAIL $rel"
        foreach ($e in $errs) {
            Write-Host ("  L{0}: {1}" -f $e.Extent.StartLineNumber, $e.Message)
        }
        $failed++
    }
    else {
        Write-Host "OK   $rel"
    }
}
if ($failed) { exit 1 }
exit 0
