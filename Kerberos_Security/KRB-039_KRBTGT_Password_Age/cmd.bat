@echo off
REM KRB-039: KRBTGT Password Age
echo [KRB-039] KRBTGT Password Age
echo Severity: HIGH ^| Risk: 8/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
