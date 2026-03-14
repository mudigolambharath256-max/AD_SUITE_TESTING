@echo off
REM LDAP-003: Anonymous LDAP Bind Allowed
echo [LDAP-003] Anonymous LDAP Bind Allowed
echo Severity: CRITICAL ^| Risk: 10/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
