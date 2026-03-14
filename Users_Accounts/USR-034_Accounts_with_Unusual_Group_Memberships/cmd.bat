@echo off
REM USR-034: Accounts with Unusual Group Memberships
echo Running Accounts with Unusual Group Memberships...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
