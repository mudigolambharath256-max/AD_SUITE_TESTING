@echo off
echo ============================================
echo DC-003 - Forest Functional Level (CMD)
echo ============================================
echo.

REM Get Configuration Naming Context
for /f "tokens=2 delims=:" %%A in ('dsquery * "CN=Partitions,CN=Configuration,DC=mahishmati,DC=org" -scope base -attr distinguishedName ^| find ":"') do set CONFIGDN=%%A

echo Configuration Naming Context:
echo %CONFIGDN%
echo.

echo Querying crossRefContainer objects...
echo.

dsquery * "CN=Partitions,CN=Configuration,DC=mahishmati,DC=org" ^
 -filter "(objectClass=crossRefContainer)" ^
 -attr name distinguishedName msDS-Behavior-Version

echo.
echo ===== Completed =====
pause
