@echo off
REM NET-007: WINS Server Configuration
echo [NET-007] WINS Server Configuration
echo Severity: MEDIUM ^| Risk: 5/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
