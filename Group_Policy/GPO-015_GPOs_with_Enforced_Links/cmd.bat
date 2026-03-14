REM Check: GPOs with Enforced Links
REM Category: Group Policy
REM Severity: info
REM ID: GPO-015
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=organizationalUnit)(gPLink=*2*))

dsquery * -filter "(&(objectClass=organizationalUnit)(gPLink=*2*))" -limit 0 -attr name distinguishedname ou gplink
