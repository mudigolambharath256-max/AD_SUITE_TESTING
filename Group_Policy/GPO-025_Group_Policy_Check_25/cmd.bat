REM Check: Group Policy Check 25
REM Category: Group Policy
REM Severity: medium
REM ID: GPO-025
REM Requirements: dsquery (Windows RSAT DS Tools)
REM ============================================
REM NOTE: OID extensible match filters stripped (not supported by dsquery).
REM This cmd.bat returns structural inventory. Use adsi.ps1 for full detection.

@echo off
dsquery * -filter "(&(objectClass=groupPolicyContainer))" -limit 0 -attr name distinguishedName displayName
