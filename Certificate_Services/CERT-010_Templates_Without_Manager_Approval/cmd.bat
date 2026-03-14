REM Check: Templates Without Manager Approval
REM Category: Certificate Services
REM Severity: medium
REM ID: CERT-010
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=pKICertificateTemplate)(!(msPKI-Enrollment-Flag:1.2.840.113556.1.4.803:=2)))

dsquery * -filter "(&(objectClass=pKICertificateTemplate)(!(msPKI-Enrollment-Flag:1.2.840.113556.1.4.803:=2)))" -limit 0 -attr name distinguishedname cn displayname mspki-enrollment-flag
