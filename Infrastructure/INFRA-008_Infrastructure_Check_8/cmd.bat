REM Check: Infrastructure Check 8
REM Category: Infrastructure
REM Severity: medium
REM ID: INFRA-008
REM Requirements: dsquery (Windows RSAT DS Tools)
REM ============================================
REM NOTE: OID extensible match filters stripped (not supported by dsquery).
REM This cmd.bat returns structural inventory. Use adsi.ps1 for full detection.

@echo off
dsquery * -filter "(&(objectClass=site))" -limit 0 -attr name distinguishedName cn
