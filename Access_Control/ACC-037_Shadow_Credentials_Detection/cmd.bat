@echo off
REM ACC-037: Shadow Credentials Detection
echo Running Shadow Credentials Detection...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
