@echo off
REM LDAP-001: LDAP Signing Not Required
echo [LDAP-001] LDAP Signing Not Required
echo Severity: CRITICAL ^| Risk: 9/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
