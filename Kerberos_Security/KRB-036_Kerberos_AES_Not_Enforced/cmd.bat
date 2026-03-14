@echo off
REM KRB-036: Kerberos AES Not Enforced
echo [KRB-036] Kerberos AES Not Enforced
echo Severity: MEDIUM ^| Risk: 6/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
