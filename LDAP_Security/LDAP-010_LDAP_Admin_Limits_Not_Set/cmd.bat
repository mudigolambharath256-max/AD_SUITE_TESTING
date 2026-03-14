@echo off
REM LDAP-010: LDAP Admin Limits Not Set
echo [LDAP-010] LDAP Admin Limits Not Set
echo Severity: MEDIUM ^| Risk: 5/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
