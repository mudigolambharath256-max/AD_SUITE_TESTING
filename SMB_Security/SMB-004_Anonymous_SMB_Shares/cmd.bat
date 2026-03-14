@echo off
REM SMB-004: Anonymous SMB Shares
echo [SMB-004] Anonymous SMB Shares
echo Severity: CRITICAL ^| Risk: 9/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause
