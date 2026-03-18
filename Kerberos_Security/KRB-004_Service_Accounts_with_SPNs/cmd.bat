REM Check: Service Accounts with SPNs
REM Category: Kerberos Security
REM Severity: medium
REM ID: KRB-004
REM Requirements: dsquery (Windows RSAT DS Tools)
REM ============================================
REM NOTE: OID extensible match filters stripped (not supported by dsquery).
REM This cmd.bat returns structural inventory. Use adsi.ps1 for full detection.

@echo off
dsquery * -filter "(&(objectClass=user)(servicePrincipalName=*)(!(cn=krbtgt)))" -limit 0 -attr name distinguishedName samAccountName servicePrincipalName
