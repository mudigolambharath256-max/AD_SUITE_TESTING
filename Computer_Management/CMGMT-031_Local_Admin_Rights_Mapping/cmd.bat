@echo off
REM CMGMT-031: Local Admin Rights Mapping
echo Running Local Admin Rights Mapping...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
