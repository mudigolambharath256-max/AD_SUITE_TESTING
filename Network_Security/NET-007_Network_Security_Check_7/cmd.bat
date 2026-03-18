REM Check: Network Security Check 7
REM Category: Network Security
REM Severity: medium
REM ID: NET-007
REM Requirements: dsquery (Windows RSAT DS Tools)
REM ============================================
REM NOTE: OID extensible match filters stripped (not supported by dsquery).
REM This cmd.bat returns structural inventory. Use adsi.ps1 for full detection.

@echo off
dsquery * -filter "(&(objectCategory=computer))" -limit 0 -attr name distinguishedName samAccountName
