REM Check: KRBTGT Account
REM Category: Authentication
REM Severity: critical
REM ID: AUTH-005
REM Requirements: dsquery (Windows RSAT DS Tools)
REM ============================================
REM NOTE: OID extensible match filters stripped (not supported by dsquery).
REM This cmd.bat returns structural inventory. Use adsi.ps1 for full detection.

@echo off
dsquery * -filter "(&(objectClass=user)(cn=krbtgt))" -limit 0 -attr name distinguishedName samAccountName pwdLastSet whenChanged
