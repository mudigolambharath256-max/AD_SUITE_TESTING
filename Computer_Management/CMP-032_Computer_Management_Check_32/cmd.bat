REM Check: Computer Management Check 32
REM Category: Computer Management
REM Severity: medium
REM ID: CMP-032
REM Requirements: dsquery (Windows RSAT DS Tools)
REM ============================================
REM NOTE: OID extensible match filters stripped (not supported by dsquery).
REM This cmd.bat returns structural inventory. Use adsi.ps1 for full detection.

@echo off
dsquery * -filter "(&(objectCategory=computer))" -limit 0 -attr name distinguishedName samAccountName
