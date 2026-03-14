@echo off
REM KRB-034: S4U2Self Abuse Detection
echo [KRB-034] S4U2Self Abuse Detection
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
