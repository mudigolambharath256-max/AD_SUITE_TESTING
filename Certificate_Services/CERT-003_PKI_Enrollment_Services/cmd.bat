REM Check: PKI Enrollment Services
REM Category: Certificate Services
REM Severity: medium
REM ID: CERT-003
REM Requirements: dsquery (Windows RSAT DS Tools)
REM ============================================
REM NOTE: OID extensible match filters stripped (not supported by dsquery).
REM This cmd.bat returns structural inventory. Use adsi.ps1 for full detection.

@echo off
dsquery * -filter "(&(objectClass=pKIEnrollmentService))" -limit 0 -attr name distinguishedName cn dNSHostName
