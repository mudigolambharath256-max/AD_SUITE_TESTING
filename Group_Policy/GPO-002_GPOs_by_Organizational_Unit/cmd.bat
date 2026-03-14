REM Check: GPOs by Organizational Unit
REM Category: Group Policy
REM Severity: info
REM ID: GPO-002
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=organizationalUnit)(gPLink=*))

dsquery * -filter "(&(objectClass=organizationalUnit)(gPLink=*))" -limit 0 -attr name distinguishedname ou gplink
