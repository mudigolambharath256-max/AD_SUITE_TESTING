@echo off
setlocal EnableExtensions
REM Template: run AD Suite checkers from CMD (delegates to PowerShell).
REM Usage:
REM   ADSuite-Run-Cmd.cmd adsi ACC-001
REM   ADSuite-Run-Cmd.cmd rsat ACC-001 [server]
REM   ADSuite-Run-Cmd.cmd combined ACC-001 [server]
REM   ADSuite-Run-Cmd.cmd scan

set "ENGINES_DIR=%~dp0"
for %%I in ("%ENGINES_DIR%..") do set "REPO_ROOT=%%~fI"
set "PS_EXE=powershell.exe"
where pwsh >nul 2>&1 && set "PS_EXE=pwsh"

if "%~1"=="" (
  echo Usage: %~nx0 ^<adsi^|rsat^|combined^|scan^> [args...]
  exit /b 1
)

if /I "%~1"=="adsi" (
  shift
  "%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%REPO_ROOT%\adsi.ps1" %*
  exit /b %ERRORLEVEL%
)

if /I "%~1"=="rsat" (
  shift
  "%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%ENGINES_DIR%ADSuite-Engine-Rsat.ps1" %*
  exit /b %ERRORLEVEL%
)

if /I "%~1"=="combined" (
  shift
  "%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%ENGINES_DIR%ADSuite-CombinedEngine.ps1" %*
  exit /b %ERRORLEVEL%
)

if /I "%~1"=="scan" (
  shift
  "%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%REPO_ROOT%\Invoke-ADSuiteScan.ps1" %*
  exit /b %ERRORLEVEL%
)

echo Unknown mode: %~1
exit /b 1
