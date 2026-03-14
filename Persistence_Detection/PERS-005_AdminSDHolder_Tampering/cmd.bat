@echo off
REM PERS-005: AdminSDHolder Tampering
echo [PERS-005] AdminSDHolder Tampering
echo Severity: CRITICAL ^| Risk: 9/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
