REM Check: Privileged Groups (adminCount=1)
REM Category: Access Control
REM Severity: high
REM ID: ACC-002
REM Requirements: dsquery (Windows RSAT DS Tools)
REM ============================================
REM NOTE: OID extensible match filters stripped (not supported by dsquery).
REM This cmd.bat returns structural inventory. Use adsi.ps1 for full detection.

@echo off
dsquery * -filter "(&(objectClass=group)(adminCount=1))" -limit 0 -attr name distinguishedName cn member
