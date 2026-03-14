@echo off
REM PRV-032: Admin Logons from Non PAW
echo Running Admin Logons from Non PAW...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
