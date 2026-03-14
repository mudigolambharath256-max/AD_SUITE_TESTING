REM Check: ESC6: CA Allowing SAN in Requests
REM Category: Certificate Services
REM Severity: high
REM ID: CERT-020
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=pKIEnrollmentService)

dsquery * -filter "(objectClass=pKIEnrollmentService)" -limit 0 -attr name distinguishedname cn dnshostname flags
