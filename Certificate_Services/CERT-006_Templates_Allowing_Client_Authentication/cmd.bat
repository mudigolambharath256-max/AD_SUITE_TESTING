REM Check: Templates Allowing Client Authentication
REM Category: Certificate Services
REM Severity: high
REM ID: CERT-006
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=pKICertificateTemplate)(pKIExtendedKeyUsage=1.3.6.1.5.5.7.3.2))

dsquery * -filter "(&(objectClass=pKICertificateTemplate)(pKIExtendedKeyUsage=1.3.6.1.5.5.7.3.2))" -limit 0 -attr name distinguishedname cn displayname pkiextendedkeyusage mspki-certificate-name-flag
