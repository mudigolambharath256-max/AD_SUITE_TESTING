REM Check: Backup Recovery Check 4
REM Category: Backup Recovery
REM Severity: medium
REM ID: BCK-004
REM Requirements: dsquery (Windows RSAT DS Tools)
REM ============================================
REM NOTE: OID extensible match filters stripped (not supported by dsquery).
REM This cmd.bat returns structural inventory. Use adsi.ps1 for full detection.

@echo off
dsquery * -filter "(&(objectClass=domainDNS))" -limit 0 -attr name distinguishedName
