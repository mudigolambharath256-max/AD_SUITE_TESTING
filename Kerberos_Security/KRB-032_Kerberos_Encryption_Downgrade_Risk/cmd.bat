@echo off
REM KRB-032: Kerberos Encryption Downgrade Risk
echo [KRB-032] Kerberos Encryption Downgrade Risk
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
