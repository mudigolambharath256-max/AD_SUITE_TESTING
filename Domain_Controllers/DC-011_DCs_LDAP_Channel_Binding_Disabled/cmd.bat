REM Check: DCs LDAP Channel Binding Disabled
REM Category: Domain Controllers
REM Severity: high
REM ID: DC-011
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
echo === DCs LDAP Channel Binding Disabled ===
echo.

REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))

echo Querying Domain Controllers...
dsquery * -filter "(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))" -limit 0 -attr name distinguishedname dnshostname operatingsystem > temp_dcs.txt

echo.
echo Checking LDAP Channel Binding configuration on each DC...
echo.

for /f "skip=1 tokens=1,2,3,4" %%a in (temp_dcs.txt) do (
    if not "%%c"=="" (
        echo Checking DC: %%c
        reg query "\\%%c\HKLM\SYSTEM\CurrentControlSet\Services\NTDS\Parameters" /v LdapEnforceChannelBinding 2>nul
        if errorlevel 1 (
            echo   WARNING: Unable to access registry on %%c or key not found
            echo   Name: %%a
            echo   DN: %%b
            echo   DNS: %%c
            echo   OS: %%d
            echo   Channel Binding: UNKNOWN - Registry Unavailable
            echo   Severity: UNKNOWN
            echo   MITRE: T1557
            echo   ----------------------------------------
        ) else (
            for /f "tokens=3" %%v in ('reg query "\\%%c\HKLM\SYSTEM\CurrentControlSet\Services\NTDS\Parameters" /v LdapEnforceChannelBinding 2^>nul ^| find "LdapEnforceChannelBinding"') do (
                if "%%v"=="0x0" (
                    echo   FINDING: LDAP Channel Binding set to Never
                    echo   Name: %%a
                    echo   DN: %%b
                    echo   DNS: %%c
                    echo   OS: %%d
                    echo   Channel Binding: Never
                    echo   Registry Value: 0
                    echo   Severity: HIGH
                    echo   MITRE: T1557
                    echo   ----------------------------------------
                ) else if "%%v"=="0x1" (
                    echo   FINDING: LDAP Channel Binding set to When Supported
                    echo   Name: %%a
                    echo   DN: %%b
                    echo   DNS: %%c
                    echo   OS: %%d
                    echo   Channel Binding: When Supported
                    echo   Registry Value: 1
                    echo   Severity: HIGH
                    echo   MITRE: T1557
                    echo   ----------------------------------------
                ) else if "%%v"=="0x2" (
                    echo   OK: LDAP Channel Binding properly configured on %%c
                ) else (
                    echo   FINDING: LDAP Channel Binding unknown value
                    echo   Name: %%a
                    echo   DN: %%b
                    echo   DNS: %%c
                    echo   OS: %%d
                    echo   Channel Binding: Unknown/Not Set
                    echo   Registry Value: %%v
                    echo   Severity: HIGH
                    echo   MITRE: T1557
                    echo   ----------------------------------------
                )
            )
        )
    )
)

del temp_dcs.txt 2>nul
echo.
echo === LDAP Channel Binding Check Complete ===