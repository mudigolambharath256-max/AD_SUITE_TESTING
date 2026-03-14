REM Check: Templates Allowing Renewal with Different Key
REM Category: Certificate Services
REM Severity: low
REM ID: CERT-019
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=pKICertificateTemplate)(msPKI-Enrollment-Flag:1.2.840.113556.1.4.803:=32))

dsquery * -filter "(&(objectClass=pKICertificateTemplate)(msPKI-Enrollment-Flag:1.2.840.113556.1.4.803:=32))" -limit 0 -attr name distinguishedname cn displayname mspki-enrollment-flag
