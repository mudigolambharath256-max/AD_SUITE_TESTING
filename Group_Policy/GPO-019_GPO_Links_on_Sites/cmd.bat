REM Check: GPO Links on Sites
REM Category: Group Policy
REM Severity: info
REM ID: GPO-019
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=site)(gPLink=*))

dsquery * -filter "(&(objectClass=site)(gPLink=*))" -limit 0 -attr name distinguishedname cn gplink
