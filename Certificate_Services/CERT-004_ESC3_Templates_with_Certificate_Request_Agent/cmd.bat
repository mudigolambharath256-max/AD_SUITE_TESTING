REM Check: ESC3: Templates with Certificate Request Agent
REM Category: Certificate Services
REM Severity: critical
REM ID: CERT-004
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=pKICertificateTemplate)(pKIExtendedKeyUsage=1.3.6.1.4.1.311.20.2.1))

dsquery * -filter "(&(objectClass=pKICertificateTemplate)(pKIExtendedKeyUsage=1.3.6.1.4.1.311.20.2.1))" -limit 0 -attr name distinguishedname cn displayname pkiextendedkeyusage
