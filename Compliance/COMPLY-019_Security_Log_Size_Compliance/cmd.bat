@echo off
REM COMPLY-019: Security Log Size Compliance
echo [CMP-019] Security Log Size Compliance
echo Severity: MEDIUM ^| Risk: 6/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
