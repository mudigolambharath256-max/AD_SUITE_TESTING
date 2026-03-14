@echo off
REM Check: DCs Replication Failures
REM Category: Domain Controllers
REM Severity: critical
REM ID: DC-013
REM Requirements: dsquery (RSAT DS tools)
REM ============================================
REM Query: nTDSDSA objects in Configuration NC for replication metadata

REM LDAP search (CMD + dsquery)
REM Note: CMD has limited replication metadata access, use repadmin for detailed info

echo === Domain Controllers Replication Status ===
echo.

REM Get all Domain Controllers
echo Finding Domain Controllers...
dsquery computer -filter "(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))" -attr name dNSHostName distinguishedName

echo.
echo === Replication Summary (use repadmin for detailed analysis) ===
echo Note: For detailed replication failure analysis, run:
echo   repadmin /showrepl * /csv
echo   repadmin /replsummary
echo   repadmin /queue *

REM Basic replication check using repadmin if available
where repadmin >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo.
    echo Running basic replication summary...
    repadmin /replsummary
) else (
    echo.
    echo repadmin not found - install RSAT AD DS tools for detailed replication analysis
)