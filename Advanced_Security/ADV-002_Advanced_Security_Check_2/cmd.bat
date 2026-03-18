REM Check: Advanced Security Check 2
REM Category: Advanced Security
REM Severity: high
REM ID: ADV-002
REM Requirements: dsquery (Windows RSAT DS Tools)
REM ============================================
REM NOTE: OID extensible match filters stripped (not supported by dsquery).
REM This cmd.bat returns structural inventory. Use adsi.ps1 for full detection.

@echo off
dsquery * -filter "(&(objectCategory=computer)(primaryGroupID=516))" -limit 0 -attr name distinguishedName samAccountName
