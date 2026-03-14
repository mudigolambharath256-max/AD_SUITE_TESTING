REM Check: Accounts with Certificate Published
REM Category: Certificate Services
REM Severity: info
REM ID: CERT-023
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(userCertificate=*))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(userCertificate=*))" -limit 0 -attr name distinguishedname samaccountname usercertificate
