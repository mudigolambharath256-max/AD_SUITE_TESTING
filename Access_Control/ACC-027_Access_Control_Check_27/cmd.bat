REM Check: Access Control Check 27
REM Category: Access Control
REM Severity: medium
REM ID: ACC-027
REM Requirements: dsquery (Windows RSAT DS Tools)
REM ============================================
REM NOTE: OID extensible match filters stripped (not supported by dsquery).
REM This cmd.bat returns structural inventory. Use adsi.ps1 for full detection.

@echo off
dsquery * -filter "(&(objectClass=user)(!))" -limit 0 -attr name distinguishedName samAccountName
