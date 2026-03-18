REM Check: LDAP Security Check 2
REM Category: LDAP Security
REM Severity: medium
REM ID: LDAP-002
REM Requirements: dsquery (Windows RSAT DS Tools)
REM ============================================
REM NOTE: OID extensible match filters stripped (not supported by dsquery).
REM This cmd.bat returns structural inventory. Use adsi.ps1 for full detection.

@echo off
dsquery * -filter "(&(objectClass=domainDNS))" -limit 0 -attr name distinguishedName
