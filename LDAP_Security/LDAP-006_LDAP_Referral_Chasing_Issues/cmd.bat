@echo off
REM LDAP-006: LDAP Referral Chasing Issues
echo [LDAP-006] LDAP Referral Chasing Issues
echo Severity: LOW ^| Risk: 3/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
