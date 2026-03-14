REM Check: Templates Enrolled by Everyone
REM Category: Certificate Services
REM Severity: high
REM ID: CERT-026
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=pKICertificateTemplate)

dsquery * -filter "(objectClass=pKICertificateTemplate)" -limit 0 -attr name distinguishedname cn displayname ntsecuritydescriptor
