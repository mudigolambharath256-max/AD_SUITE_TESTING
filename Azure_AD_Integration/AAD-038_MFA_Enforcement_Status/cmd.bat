@echo off
REM AAD-038: MFA Enforcement Status
echo [AAD-038] MFA Enforcement Status
echo Severity: CRITICAL ^| Risk: 9/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
