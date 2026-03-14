@echo off
REM AUTH-032: Accounts with Blank Passwords
echo Running Accounts with Blank Passwords...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
