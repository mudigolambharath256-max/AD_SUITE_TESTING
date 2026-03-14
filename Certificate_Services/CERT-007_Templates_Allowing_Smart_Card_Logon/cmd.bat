REM Check: Templates Allowing Smart Card Logon
REM Category: Certificate Services
REM Severity: high
REM ID: CERT-007
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=pKICertificateTemplate)(pKIExtendedKeyUsage=1.3.6.1.4.1.311.20.2.2))

dsquery * -filter "(&(objectClass=pKICertificateTemplate)(pKIExtendedKeyUsage=1.3.6.1.4.1.311.20.2.2))" -limit 0 -attr name distinguishedname cn displayname pkiextendedkeyusage
