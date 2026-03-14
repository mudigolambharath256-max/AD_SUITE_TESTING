@echo off
REM DCONF-031: Unexpected Schema Modifications
echo Running Unexpected Schema Modifications...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
