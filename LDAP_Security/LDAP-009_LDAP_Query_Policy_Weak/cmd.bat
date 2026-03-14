@echo off
REM LDAP-009: LDAP Query Policy Weak
echo [LDAP-009] LDAP Query Policy Weak
echo Severity: MEDIUM ^| Risk: 6/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
