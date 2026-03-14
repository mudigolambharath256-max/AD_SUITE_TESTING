@echo off
REM CMGMT-034: PSRemoting Enabled Computers
echo Running PSRemoting Enabled Computers...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
