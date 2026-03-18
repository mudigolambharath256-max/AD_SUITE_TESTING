REM Check: Miscellaneous Check 752
REM Category: Miscellaneous
REM Severity: low
REM ID: MISC-752
REM Requirements: dsquery (Windows RSAT DS Tools)
REM ============================================
REM NOTE: OID extensible match filters stripped (not supported by dsquery).
REM This cmd.bat returns structural inventory. Use adsi.ps1 for full detection.

@echo off
dsquery * -filter "(&(objectClass=*))" -limit 0 -attr name distinguishedName
