REM Check: Privileged Access Check 21
REM Category: Privileged Access
REM Severity: high
REM ID: PRV-021
REM Requirements: dsquery (Windows RSAT DS Tools)
REM ============================================
REM NOTE: OID extensible match filters stripped (not supported by dsquery).
REM This cmd.bat returns structural inventory. Use adsi.ps1 for full detection.

@echo off
dsquery * -filter "(&(objectClass=user)(adminCount=1))" -limit 0 -attr name distinguishedName samAccountName adminCount
