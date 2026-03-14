@echo off
REM KRB-044: Kerberos Clock Skew Issues
echo [KRB-044] Kerberos Clock Skew Issues
echo Severity: MEDIUM ^| Risk: 4/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
