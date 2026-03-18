REM Check: Infrastructure Check 18
REM Category: Infrastructure
REM Severity: medium
REM ID: INFRA-018
REM Requirements: dsquery (Windows RSAT DS Tools)
REM ============================================
REM NOTE: OID extensible match filters stripped (not supported by dsquery).
REM This cmd.bat returns structural inventory. Use adsi.ps1 for full detection.

@echo off
dsquery * -filter "(&(objectClass=site))" -limit 0 -attr name distinguishedName cn
