@echo off
REM ============================================================================
REM TMGMT-009: External Trust Relationships
REM ============================================================================
REM Category: Trust_Management
REM Description: Batch file wrapper for PowerShell execution
REM ============================================================================

echo.
echo ============================================================================
echo TMGMT-009: External Trust Relationships
echo ============================================================================
echo.

REM Check if PowerShell is available
where powershell.exe >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: PowerShell is not available on this system
    echo Please install PowerShell to run this check
    pause
    exit /b 1
)

REM Execute PowerShell script
echo Running security check...
echo.

powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0powershell.ps1"

REM Check exit code
if %ERRORLEVEL% EQU 0 (
    echo.
    echo Check completed successfully
) else (
    echo.
    echo Check failed with error code: %ERRORLEVEL%
)

echo.
pause
