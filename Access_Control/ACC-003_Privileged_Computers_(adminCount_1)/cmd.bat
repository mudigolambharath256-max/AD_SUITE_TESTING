REM Check: Privileged Computers (adminCount=1)
REM Category: Access Control
REM Severity: high
REM ID: ACC-003
REM Requirements: dsquery (Windows RSAT DS Tools)
REM ============================================
REM NOTE: OID extensible match filters stripped (not supported by dsquery).
REM This cmd.bat returns structural inventory. Use adsi.ps1 for full detection.

@echo off
dsquery * -filter "(&(objectCategory=computer)(adminCount=1))" -limit 0 -attr name distinguishedName samAccountName adminCount
