REM Check: Trust Objects Without SecurityIdentifier
REM Category: Trust Relationships
REM Severity: medium
REM ID: TRST-028
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=trustedDomain)(!(securityIdentifier=*)))

dsquery * -filter "(&(objectClass=trustedDomain)(!(securityIdentifier=*)))" -limit 0 -attr name distinguishedname cn flatname
