@echo off
REM PERS-007: Malicious SPN Additions
echo [PERS-007] Malicious SPN Additions
echo Severity: HIGH ^| Risk: 8/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
