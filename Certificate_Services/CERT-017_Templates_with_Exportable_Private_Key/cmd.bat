REM Check: Templates with Exportable Private Key
REM Category: Certificate Services
REM Severity: medium
REM ID: CERT-017
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=pKICertificateTemplate)(msPKI-Private-Key-Flag:1.2.840.113556.1.4.803:=16))

dsquery * -filter "(&(objectClass=pKICertificateTemplate)(msPKI-Private-Key-Flag:1.2.840.113556.1.4.803:=16))" -limit 0 -attr name distinguishedname cn displayname mspki-private-key-flag
