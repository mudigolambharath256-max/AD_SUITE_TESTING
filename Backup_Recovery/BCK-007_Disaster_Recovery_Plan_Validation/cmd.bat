@echo off
REM BCK-007: Disaster Recovery Plan Validation
echo [BCK-007] Disaster Recovery Plan Validation
echo Severity: MEDIUM ^| Risk: 6/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
