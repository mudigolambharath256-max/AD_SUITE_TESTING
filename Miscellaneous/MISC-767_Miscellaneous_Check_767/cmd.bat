REM Check: Miscellaneous Check 767
REM Category: Miscellaneous
REM Severity: low
REM ID: MISC-767
REM Requirements: dsquery (Windows RSAT DS Tools)
REM ============================================
REM NOTE: OID extensible match filters stripped (not supported by dsquery).
REM This cmd.bat returns structural inventory. Use adsi.ps1 for full detection.

@echo off
dsquery * -filter "(&(objectClass=*))" -limit 0 -attr name distinguishedName
