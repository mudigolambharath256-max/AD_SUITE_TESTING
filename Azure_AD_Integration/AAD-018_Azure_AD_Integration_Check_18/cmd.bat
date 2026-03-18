REM Check: Azure AD Integration Check 18
REM Category: Azure AD Integration
REM Severity: medium
REM ID: AAD-018
REM Requirements: dsquery (Windows RSAT DS Tools)
REM ============================================
REM NOTE: OID extensible match filters stripped (not supported by dsquery).
REM This cmd.bat returns structural inventory. Use adsi.ps1 for full detection.

@echo off
dsquery * -filter "(&(objectClass=user)(|(samAccountName=MSOL_*)(samAccountName=AAD_*)))" -limit 0 -attr name distinguishedName samAccountName
