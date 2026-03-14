@echo off
REM KRB-033: PAC Validation Disabled
echo [KRB-033] PAC Validation Disabled
echo Severity: CRITICAL ^| Risk: 9/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
