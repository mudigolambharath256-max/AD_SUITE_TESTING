REM Check: Users with Key Credentials
REM Category: Access Control
REM Severity: high
REM ID: ACC-009
REM Requirements: dsquery (Windows RSAT DS Tools)
REM ============================================
REM NOTE: OID extensible match filters stripped (not supported by dsquery).
REM This cmd.bat returns structural inventory. Use adsi.ps1 for full detection.

@echo off
dsquery * -filter "(&(objectClass=user)(msDS-KeyCredentialLink=*))" -limit 0 -attr name distinguishedName samAccountName msDS-KeyCredentialLink
