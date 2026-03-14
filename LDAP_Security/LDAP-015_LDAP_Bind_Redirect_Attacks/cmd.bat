@echo off
REM LDAP-015: LDAP Bind Redirect Attacks
echo [LDAP-015] LDAP Bind Redirect Attacks
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
