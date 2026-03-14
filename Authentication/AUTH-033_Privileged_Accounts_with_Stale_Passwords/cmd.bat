@echo off
REM AUTH-033: Privileged Accounts with Stale Passwords
echo Running Privileged Accounts with Stale Passwords...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
