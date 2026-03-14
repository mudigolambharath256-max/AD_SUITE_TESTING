@echo off
REM NET-006: DNS Scavenging Configuration
echo [NET-006] DNS Scavenging Configuration
echo Severity: MEDIUM ^| Risk: 5/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
