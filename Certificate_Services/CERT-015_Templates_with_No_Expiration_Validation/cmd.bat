REM Check: Templates with No Expiration Validation
REM Category: Certificate Services
REM Severity: low
REM ID: CERT-015
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=pKICertificateTemplate)(!(pKIExpirationPeriod=*)))

dsquery * -filter "(&(objectClass=pKICertificateTemplate)(!(pKIExpirationPeriod=*)))" -limit 0 -attr name distinguishedname cn displayname
