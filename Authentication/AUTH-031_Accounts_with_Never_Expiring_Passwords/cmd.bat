@echo off
REM AUTH-031: Accounts with Never Expiring Passwords
echo Running Accounts with Never Expiring Passwords...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
