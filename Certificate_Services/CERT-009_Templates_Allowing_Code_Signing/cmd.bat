REM Check: Templates Allowing Code Signing
REM Category: Certificate Services
REM Severity: high
REM ID: CERT-009
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=pKICertificateTemplate)(pKIExtendedKeyUsage=1.3.6.1.5.5.7.3.3))

dsquery * -filter "(&(objectClass=pKICertificateTemplate)(pKIExtendedKeyUsage=1.3.6.1.5.5.7.3.3))" -limit 0 -attr name distinguishedname cn displayname pkiextendedkeyusage
