@echo off
REM AAD-033: Azure AD Connect Sync Errors
echo [AAD-033] Azure AD Connect Sync Errors
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
