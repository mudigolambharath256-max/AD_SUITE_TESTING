REM Check: OUs Without GPO Links
REM Category: Group Policy
REM Severity: low
REM ID: GPO-013
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=organizationalUnit)(!(gPLink=*)))

dsquery * -filter "(&(objectClass=organizationalUnit)(!(gPLink=*)))" -limit 0 -attr name distinguishedname ou
