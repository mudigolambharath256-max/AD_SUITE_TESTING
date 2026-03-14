@echo off
REM KRB-031: Bronze Bit Attack Vulnerable Accounts
echo [KRB-031] Bronze Bit Attack Vulnerable Accounts
echo Severity: HIGH ^| Risk: 8/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
