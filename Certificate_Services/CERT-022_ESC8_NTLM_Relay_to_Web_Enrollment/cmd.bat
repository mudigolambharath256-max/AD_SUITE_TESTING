REM Check: ESC8: NTLM Relay to Web Enrollment
REM Category: Certificate Services
REM Severity: high
REM ID: CERT-022
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=pKIEnrollmentService)

dsquery * -filter "(objectClass=pKIEnrollmentService)" -limit 0 -attr name distinguishedname cn dnshostname
