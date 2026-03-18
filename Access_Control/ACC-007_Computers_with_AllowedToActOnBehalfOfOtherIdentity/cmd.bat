REM Check: Computers with AllowedToActOnBehalfOfOtherIdentity
REM Category: Access Control
REM Severity: high
REM ID: ACC-007
REM Requirements: dsquery (Windows RSAT DS Tools)
REM ============================================
REM NOTE: OID extensible match filters stripped (not supported by dsquery).
REM This cmd.bat returns structural inventory. Use adsi.ps1 for full detection.

@echo off
dsquery * -filter "(&(objectCategory=computer)(msDS-AllowedToActOnBehalfOfOtherIdentity=*))" -limit 0 -attr name distinguishedName samAccountName msDS-AllowedToActOnBehalfOfOtherIdentity
