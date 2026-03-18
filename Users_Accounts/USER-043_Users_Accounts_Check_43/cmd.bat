REM Check: Users Accounts Check 43
REM Category: Users Accounts
REM Severity: info
REM ID: USER-043
REM Requirements: dsquery (Windows RSAT DS Tools)
REM ============================================
REM NOTE: OID extensible match filters stripped (not supported by dsquery).
REM This cmd.bat returns structural inventory. Use adsi.ps1 for full detection.

@echo off
dsquery * -filter "(&(objectClass=user))" -limit 0 -attr name distinguishedName samAccountName
