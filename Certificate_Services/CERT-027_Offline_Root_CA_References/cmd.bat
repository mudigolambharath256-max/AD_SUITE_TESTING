REM Check: Offline Root CA References
REM Category: Certificate Services
REM Severity: info
REM ID: CERT-027
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=certificationAuthority)(cn=*))

dsquery * -filter "(&(objectClass=certificationAuthority)(cn=*))" -limit 0 -attr name distinguishedname cn cacertificate certificaterevocationlist
