@echo off
REM LDAP-013: LDAP Audit Logging Disabled
echo [LDAP-013] LDAP Audit Logging Disabled
echo Severity: MEDIUM ^| Risk: 6/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
