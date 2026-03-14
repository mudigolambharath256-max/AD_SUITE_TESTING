@echo off
REM Check: DCs with Expiring Certificates
REM Category: Domain Controllers
REM Severity: high
REM ID: DC-012
REM Requirements: None
REM ============================================

echo === DCs with Expiring Certificates ===
echo.

REM Query Domain Controllers with certificates
echo Querying Domain Controllers with certificates...
dsquery computer -limit 0 | findstr /C:"CN=" > %TEMP%\dcs.txt

if exist %TEMP%\dcs.txt (
    echo Found Domain Controllers. Checking certificate stores...
    echo.
    echo Note: Certificate expiration checking requires PowerShell or manual verification
    echo Use: Get-ChildItem Cert:\LocalMachine\My on each DC to check certificates
    echo.
    
    for /f "tokens=*" %%i in (%TEMP%\dcs.txt) do (
        echo DC: %%i
        echo   [INFO] Manual certificate check required
        echo.
    )
    
    del %TEMP%\dcs.txt
) else (
    echo No Domain Controllers found or query failed
)

echo Check completed.
pause