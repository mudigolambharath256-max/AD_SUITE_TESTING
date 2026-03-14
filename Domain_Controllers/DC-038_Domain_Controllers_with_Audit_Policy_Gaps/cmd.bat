@echo off
REM DC-038: Domain Controllers with Audit Policy Gaps
echo Running Domain Controllers with Audit Policy Gaps...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
