@echo off
REM SVC-031: Service Accounts with Interactive Logon
echo Running Service Accounts with Interactive Logon...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
