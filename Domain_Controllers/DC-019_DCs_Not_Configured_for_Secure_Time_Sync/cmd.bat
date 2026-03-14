@echo off
REM DC-043: DCs Not Configured for Secure Time Sync
REM Identifies Domain Controllers with insecure time synchronization

echo DC-043: DCs Not Configured for Secure Time Sync
echo ============================================================
echo.

echo Querying Domain Controllers...
echo.

REM Query all Domain Controllers
for /f "tokens=*" %%i in ('dsquery server') do (
    REM Extract hostname from DN
    for /f "tokens=1 delims=," %%j in ("%%i") do (
        set "dcname=%%j"
        set "dcname=!dcname:CN=!"
        echo Checking: !dcname!
        echo   [INFO] Time sync check requires PowerShell or WMI access
        echo   [INFO] Use powershell.ps1 for complete functionality
        echo.
    )
)

echo.
echo Check complete.
echo For detailed time sync analysis, use the PowerShell version.
pause
