@echo off
REM BCK-003: Tombstone Lifetime Check
echo [BCK-003] Tombstone Lifetime Check
echo Severity: MEDIUM ^| Risk: 5/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
