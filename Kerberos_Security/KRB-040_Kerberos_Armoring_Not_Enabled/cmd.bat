@echo off
REM KRB-040: Kerberos Armoring Not Enabled
echo [KRB-040] Kerberos Armoring Not Enabled
echo Severity: MEDIUM ^| Risk: 6/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
