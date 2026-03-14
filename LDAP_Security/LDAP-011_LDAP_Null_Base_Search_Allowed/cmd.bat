@echo off
REM LDAP-011: LDAP Null Base Search Allowed
echo [LDAP-011] LDAP Null Base Search Allowed
echo Severity: MEDIUM ^| Risk: 6/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
