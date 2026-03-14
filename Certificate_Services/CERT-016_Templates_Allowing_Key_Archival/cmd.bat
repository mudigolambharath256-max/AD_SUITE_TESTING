REM Check: Templates Allowing Key Archival
REM Category: Certificate Services
REM Severity: medium
REM ID: CERT-016
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=pKICertificateTemplate)(msPKI-Enrollment-Flag:1.2.840.113556.1.4.803:=8))

dsquery * -filter "(&(objectClass=pKICertificateTemplate)(msPKI-Enrollment-Flag:1.2.840.113556.1.4.803:=8))" -limit 0 -attr name distinguishedname cn displayname mspki-enrollment-flag
