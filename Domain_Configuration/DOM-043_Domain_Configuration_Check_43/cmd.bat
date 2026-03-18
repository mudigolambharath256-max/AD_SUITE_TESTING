REM Check: Domain Configuration Check 43
REM Category: Domain Configuration
REM Severity: medium
REM ID: DOM-043
REM Requirements: dsquery (Windows RSAT DS Tools)
REM ============================================
REM NOTE: OID extensible match filters stripped (not supported by dsquery).
REM This cmd.bat returns structural inventory. Use adsi.ps1 for full detection.

@echo off
dsquery * -filter "(&(objectClass=domainDNS))" -limit 0 -attr name distinguishedName
