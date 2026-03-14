@echo off
REM BCK-005: AD Recycle Bin Status
echo [BCK-005] AD Recycle Bin Status
echo Severity: MEDIUM ^| Risk: 6/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
