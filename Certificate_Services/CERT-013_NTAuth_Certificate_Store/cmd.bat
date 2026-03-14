REM Check: NTAuth Certificate Store
REM Category: Certificate Services
REM Severity: info
REM ID: CERT-013
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=certificationAuthority)(cn=NTAuthCertificates))

dsquery * -filter "(&(objectClass=certificationAuthority)(cn=NTAuthCertificates))" -limit 0 -attr name distinguishedname cn cacertificate
