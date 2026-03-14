REM Check: ESC4: Templates with Weak Access Control
REM Category: Certificate Services
REM Severity: high
REM ID: CERT-005
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=pKICertificateTemplate)

dsquery * -filter "(objectClass=pKICertificateTemplate)" -limit 0 -attr name distinguishedname cn displayname ntsecuritydescriptor
