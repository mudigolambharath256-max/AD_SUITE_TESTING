REM Check: Orphaned Foreign Security Principals
REM Category: Trust Relationships
REM Severity: medium
REM ID: TRST-019
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=foreignSecurityPrincipal)(cn=S-1-5-21-*))

dsquery * -filter "(&(objectClass=foreignSecurityPrincipal)(cn=S-1-5-21-*))" -limit 0 -attr name distinguishedname cn objectsid memberof
