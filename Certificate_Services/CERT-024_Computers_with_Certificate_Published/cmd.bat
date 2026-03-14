REM Check: Computers with Certificate Published
REM Category: Certificate Services
REM Severity: info
REM ID: CERT-024
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(userCertificate=*))

dsquery * -filter "(&(objectCategory=computer)(userCertificate=*))" -limit 0 -attr name distinguishedname samaccountname usercertificate operatingsystem
