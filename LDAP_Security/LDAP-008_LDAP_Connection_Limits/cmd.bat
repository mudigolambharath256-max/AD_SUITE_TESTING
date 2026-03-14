@echo off
REM LDAP-008: LDAP Connection Limits
echo [LDAP-008] LDAP Connection Limits
echo Severity: MEDIUM ^| Risk: 5/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
