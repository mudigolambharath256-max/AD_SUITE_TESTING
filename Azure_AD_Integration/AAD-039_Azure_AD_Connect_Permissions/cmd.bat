@echo off
REM AAD-039: Azure AD Connect Permissions
echo [AAD-039] Azure AD Connect Permissions
echo Severity: HIGH ^| Risk: 8/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
