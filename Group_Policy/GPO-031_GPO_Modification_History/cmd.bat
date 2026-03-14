@echo off
REM GPO-031: GPO Modification History
echo Running GPO Modification History...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
