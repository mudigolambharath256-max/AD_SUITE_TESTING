@echo off
REM LDAP-007: LDAP Server Certificate Invalid
echo [LDAP-007] LDAP Server Certificate Invalid
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
