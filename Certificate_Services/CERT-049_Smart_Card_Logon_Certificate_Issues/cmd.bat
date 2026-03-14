@echo off
REM CERT-049: Smart Card Logon Certificate Issues
echo [CERT-049] Smart Card Logon Certificate Issues
echo Severity: MEDIUM ^| Risk: 6/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
