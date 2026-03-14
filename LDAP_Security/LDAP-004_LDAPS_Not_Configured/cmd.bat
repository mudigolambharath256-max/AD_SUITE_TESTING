@echo off
REM LDAP-004: LDAPS Not Configured
echo [LDAP-004] LDAPS Not Configured
echo Severity: HIGH ^| Risk: 8/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
