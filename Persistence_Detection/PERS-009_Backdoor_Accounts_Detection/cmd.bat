@echo off
REM PERS-009: Backdoor Accounts Detection
echo [PERS-009] Backdoor Accounts Detection
echo Severity: HIGH ^| Risk: 8/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
