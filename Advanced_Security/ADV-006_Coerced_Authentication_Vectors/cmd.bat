@echo off
REM ADV-006: Coerced Authentication Vectors
echo [ADV-006] Coerced Authentication Vectors
echo Severity: HIGH ^| Risk: 8/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
