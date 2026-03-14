REM Check: Anonymous LDAP Access Check
REM Category: Authentication
REM Severity: high
REM ID: AUTH-029
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=domainDNS)(dSHeuristics=0000002*))

dsquery * -filter "(&(objectClass=domainDNS)(dSHeuristics=0000002*))" -limit 0 -attr name distinguishedname dsheuristics
