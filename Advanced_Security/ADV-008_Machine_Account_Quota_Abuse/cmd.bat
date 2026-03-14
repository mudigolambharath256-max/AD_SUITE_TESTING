@echo off
REM ADV-008: Machine Account Quota Abuse
echo [ADV-008] Machine Account Quota Abuse
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
