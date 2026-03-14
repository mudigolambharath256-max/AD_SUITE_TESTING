REM Check: ESC7: CA with Manage Certificates Permission
REM Category: Certificate Services
REM Severity: high
REM ID: CERT-021
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=pKIEnrollmentService)

dsquery * -filter "(objectClass=pKIEnrollmentService)" -limit 0 -attr name distinguishedname cn dnshostname ntsecuritydescriptor
