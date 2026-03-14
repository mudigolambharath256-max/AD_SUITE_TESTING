@echo off
REM AAD-032: Password Hash Sync Status
echo Running Password Hash Sync Status...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
