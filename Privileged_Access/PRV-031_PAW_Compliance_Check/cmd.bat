@echo off
REM PRV-031: PAW Compliance Check
echo Running PAW Compliance Check...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
