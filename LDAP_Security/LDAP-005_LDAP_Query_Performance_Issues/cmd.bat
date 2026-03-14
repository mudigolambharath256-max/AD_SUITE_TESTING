@echo off
REM LDAP-005: LDAP Query Performance Issues
echo [LDAP-005] LDAP Query Performance Issues
echo Severity: LOW ^| Risk: 3/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
