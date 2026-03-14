@echo off
REM PERS-012: Suspicious Object Creation Patterns
echo [PERS-012] Suspicious Object Creation Patterns
echo Severity: MEDIUM ^| Risk: 6/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
