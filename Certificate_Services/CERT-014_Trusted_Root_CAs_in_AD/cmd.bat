REM Check: Trusted Root CAs in AD
REM Category: Certificate Services
REM Severity: info
REM ID: CERT-014
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=certificationAuthority)(cn=*))

dsquery * -filter "(&(objectClass=certificationAuthority)(cn=*))" -limit 0 -attr name distinguishedname cn cacertificate
