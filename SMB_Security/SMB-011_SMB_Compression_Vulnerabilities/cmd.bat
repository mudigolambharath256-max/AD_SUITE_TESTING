@echo off
REM SMB-011: SMB Compression Vulnerabilities
echo [SMB-011] SMB Compression Vulnerabilities
echo Severity: MEDIUM ^| Risk: 5/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
