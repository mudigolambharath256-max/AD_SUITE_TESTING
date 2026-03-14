@echo off
REM USR-035: Accounts with Suspicious Naming Patterns
echo Running Accounts with Suspicious Naming Patterns...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
