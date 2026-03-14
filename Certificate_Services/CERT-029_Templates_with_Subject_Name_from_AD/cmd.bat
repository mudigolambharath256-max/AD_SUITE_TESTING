REM Check: Templates with Subject Name from AD
REM Category: Certificate Services
REM Severity: info
REM ID: CERT-029
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=pKICertificateTemplate)(msPKI-Certificate-Name-Flag:1.2.840.113556.1.4.803:=134217728))

dsquery * -filter "(&(objectClass=pKICertificateTemplate)(msPKI-Certificate-Name-Flag:1.2.840.113556.1.4.803:=134217728))" -limit 0 -attr name distinguishedname cn displayname mspki-certificate-name-flag
