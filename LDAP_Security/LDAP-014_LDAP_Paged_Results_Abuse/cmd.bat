@echo off
REM LDAP-014: LDAP Paged Results Abuse
echo [LDAP-014] LDAP Paged Results Abuse
echo Severity: MEDIUM ^| Risk: 5/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
