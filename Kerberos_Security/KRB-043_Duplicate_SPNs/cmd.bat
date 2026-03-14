@echo off
REM KRB-043: Duplicate SPNs
echo [KRB-043] Duplicate SPNs
echo Severity: MEDIUM ^| Risk: 5/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
