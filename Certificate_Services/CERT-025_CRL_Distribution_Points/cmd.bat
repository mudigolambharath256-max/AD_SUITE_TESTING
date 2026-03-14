REM Check: CRL Distribution Points
REM Category: Certificate Services
REM Severity: info
REM ID: CERT-025
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=cRLDistributionPoint))

dsquery * -filter "(&(objectClass=cRLDistributionPoint))" -limit 0 -attr name distinguishedname cn
