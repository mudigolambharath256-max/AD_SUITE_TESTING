REM Check: Templates Allowing PKINIT Client Auth
REM Category: Certificate Services
REM Severity: high
REM ID: CERT-008
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=pKICertificateTemplate)(pKIExtendedKeyUsage=1.3.6.1.5.2.3.4))

dsquery * -filter "(&(objectClass=pKICertificateTemplate)(pKIExtendedKeyUsage=1.3.6.1.5.2.3.4))" -limit 0 -attr name distinguishedname cn displayname pkiextendedkeyusage
