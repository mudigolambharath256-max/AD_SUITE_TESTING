REM Check: ESC2: Templates with Any Purpose EKU
REM Category: Certificate Services
REM Severity: critical
REM ID: CERT-003
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=pKICertificateTemplate)(|(pKIExtendedKeyUsage=2.5.29.37.0)(!(pKIExtendedKeyUsage=*))))

dsquery * -filter "(&(objectClass=pKICertificateTemplate)(|(pKIExtendedKeyUsage=2.5.29.37.0)(!(pKIExtendedKeyUsage=*))))" -limit 0 -attr name distinguishedname cn displayname pkiextendedkeyusage
