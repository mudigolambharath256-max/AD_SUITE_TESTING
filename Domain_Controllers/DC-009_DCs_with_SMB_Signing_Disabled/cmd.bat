@echo off
REM Check: DCs with SMB Signing Disabled
REM Category: Domain Controllers
REM Severity: critical
REM ID: DC-009
REM Requirements: dsquery (RSAT DS tools)
REM ============================================
REM Registry: HKLM\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters\requireSecuritySignature

REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))

echo === Domain Controllers SMB Signing Check ===
echo.

REM Query all Domain Controllers
echo Querying Domain Controllers...
dsquery * -filter "(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))" -limit 0 -attr name distinguishedName dNSHostName operatingSystem > %TEMP%\dc_list.txt

if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Failed to query Domain Controllers
    exit /b 1
)

echo.
echo Checking SMB signing configuration on each DC...
echo.
echo Name,DNSHostName,SMBSigningStatus,RegistryValue,Severity

REM Process each DC (simplified - CMD batch has limited registry access capabilities)
for /f "skip=1 tokens=1,3 delims= " %%A in (%TEMP%\dc_list.txt) do (
    if not "%%B"=="" (
        REM Attempt to check registry via reg query (requires admin rights and firewall exceptions)
        reg query "\\%%B\HKLM\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters" /v requireSecuritySignature >nul 2>&1
        if !ERRORLEVEL! EQU 0 (
            for /f "tokens=3" %%C in ('reg query "\\%%B\HKLM\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters" /v requireSecuritySignature ^| findstr "requireSecuritySignature"') do (
                if "%%C"=="0x1" (
                    echo %%A,%%B,Required,1,OK
                ) else (
                    echo %%A,%%B,Disabled,%%C,CRITICAL
                )
            )
        ) else (
            echo %%A,%%B,UNKNOWN - Registry Unavailable,Access Denied,UNKNOWN
        )
    )
)

REM Cleanup
del %TEMP%\dc_list.txt >nul 2>&1

echo.
echo === Check Complete ===
echo NOTE: This CMD implementation has limited remote registry access.
echo For comprehensive results, use adsi.ps1 or powershell.ps1 instead.