REM Check: Trust Objects Without FlatName
REM Category: Trust Relationships
REM Severity: low
REM ID: TRST-029
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=trustedDomain)(!(flatName=*)))

dsquery * -filter "(&(objectClass=trustedDomain)(!(flatName=*)))" -limit 0 -attr name distinguishedname cn
