REM Check: Certificate Services Check 34
REM Category: Certificate Services
REM Severity: medium
REM ID: CERT-034
REM Requirements: dsquery (Windows RSAT DS Tools)
REM ============================================
REM NOTE: OID extensible match filters stripped (not supported by dsquery).
REM This cmd.bat returns structural inventory. Use adsi.ps1 for full detection.

@echo off
dsquery * -filter "(&(objectClass=pKICertificateTemplate))" -limit 0 -attr name distinguishedName cn
