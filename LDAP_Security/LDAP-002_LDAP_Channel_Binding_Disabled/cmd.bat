@echo off
REM LDAP-002: LDAP Channel Binding Disabled
echo [LDAP-002] LDAP Channel Binding Disabled
echo Severity: HIGH ^| Risk: 8/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
