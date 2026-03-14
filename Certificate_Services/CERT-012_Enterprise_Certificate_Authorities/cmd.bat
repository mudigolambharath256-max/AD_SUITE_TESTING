REM Check: Enterprise Certificate Authorities
REM Category: Certificate Services
REM Severity: info
REM ID: CERT-012
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=pKIEnrollmentService)

dsquery * -filter "(objectClass=pKIEnrollmentService)" -limit 0 -attr name distinguishedname cn dnshostname cacertificate certificatetemplates
