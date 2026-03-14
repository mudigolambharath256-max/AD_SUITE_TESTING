REM Check: OUs Blocking Inheritance
REM Category: Group Policy
REM Severity: medium
REM ID: GPO-014
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=organizationalUnit)(gPOptions=1))

dsquery * -filter "(&(objectClass=organizationalUnit)(gPOptions=1))" -limit 0 -attr name distinguishedname ou gpoptions gplink
