@echo off
REM BCK-004: Deleted Object Recovery Capability
echo [BCK-004] Deleted Object Recovery Capability
echo Severity: MEDIUM ^| Risk: 5/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
