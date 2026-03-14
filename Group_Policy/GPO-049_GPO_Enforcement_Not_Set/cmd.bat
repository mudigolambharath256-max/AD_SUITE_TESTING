@echo off
REM GPO-049: GPO Enforcement Not Set
echo [GPO-049] GPO Enforcement Not Set
echo Severity: MEDIUM ^| Risk: 6/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
