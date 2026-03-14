@echo off
REM KRB-042: Kerberos Pre Auth Not Required Computers
echo [KRB-042] Kerberos Pre Auth Not Required Computers
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
