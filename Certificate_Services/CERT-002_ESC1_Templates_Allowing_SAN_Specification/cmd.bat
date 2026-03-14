REM Check: ESC1: Templates Allowing SAN Specification
REM Category: Certificate Services
REM Severity: critical
REM ID: CERT-002
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=pKICertificateTemplate)(msPKI-Certificate-Name-Flag:1.2.840.113556.1.4.803:=1))

dsquery * -filter "(&(objectClass=pKICertificateTemplate)(msPKI-Certificate-Name-Flag:1.2.840.113556.1.4.803:=1))" -limit 0 -attr name distinguishedname cn displayname mspki-certificate-name-flag pkiextendedkeyusage
