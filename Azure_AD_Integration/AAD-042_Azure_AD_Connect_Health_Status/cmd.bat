@echo off
REM AAD-042: Azure AD Connect Health Status
echo [AAD-042] Azure AD Connect Health Status
echo Severity: MEDIUM ^| Risk: 5/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
