@echo off
REM GPO-047: GPO Folder Redirection Security
echo [GPO-047] GPO Folder Redirection Security
echo Severity: MEDIUM ^| Risk: 6/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
