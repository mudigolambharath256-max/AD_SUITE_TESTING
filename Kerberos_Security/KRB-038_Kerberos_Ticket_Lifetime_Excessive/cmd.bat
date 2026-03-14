@echo off
REM KRB-038: Kerberos Ticket Lifetime Excessive
echo [KRB-038] Kerberos Ticket Lifetime Excessive
echo Severity: MEDIUM ^| Risk: 5/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
