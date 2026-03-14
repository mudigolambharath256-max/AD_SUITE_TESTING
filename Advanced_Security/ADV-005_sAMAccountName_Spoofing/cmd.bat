@echo off
REM ADV-005: sAMAccountName Spoofing
echo [ADV-005] sAMAccountName Spoofing
echo Severity: HIGH ^| Risk: 8/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
