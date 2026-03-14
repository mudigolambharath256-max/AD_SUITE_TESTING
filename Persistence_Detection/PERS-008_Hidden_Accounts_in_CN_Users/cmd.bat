@echo off
REM PERS-008: Hidden Accounts in CN Users
echo [PERS-008] Hidden Accounts in CN Users
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
