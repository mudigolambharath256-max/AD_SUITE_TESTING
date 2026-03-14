@echo off
REM ACC-034: Kerberoastable Accounts
echo Running Kerberoastable Accounts...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
