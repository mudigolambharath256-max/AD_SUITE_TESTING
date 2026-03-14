@echo off
REM DC-037: Domain Controllers with Unusual Services
echo Running Domain Controllers with Unusual Services...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
