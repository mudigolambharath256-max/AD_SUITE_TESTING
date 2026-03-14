@echo off
REM NET-008: IPv6 Security Configuration
echo [NET-008] IPv6 Security Configuration
echo Severity: MEDIUM ^| Risk: 6/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
