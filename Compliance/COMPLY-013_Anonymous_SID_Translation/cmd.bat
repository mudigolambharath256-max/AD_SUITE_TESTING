@echo off
REM COMPLY-013: Anonymous SID Translation
echo [CMP-013] Anonymous SID Translation
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
