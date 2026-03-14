REM Check: Foreign Security Principals
REM Category: Trust Relationships
REM Severity: info
REM ID: TRST-018
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=foreignSecurityPrincipal)

dsquery * -filter "(objectClass=foreignSecurityPrincipal)" -limit 0 -attr name distinguishedname cn objectsid
