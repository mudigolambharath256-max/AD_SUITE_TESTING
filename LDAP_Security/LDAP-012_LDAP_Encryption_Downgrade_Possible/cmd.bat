@echo off
REM LDAP-012: LDAP Encryption Downgrade Possible
echo [LDAP-012] LDAP Encryption Downgrade Possible
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
