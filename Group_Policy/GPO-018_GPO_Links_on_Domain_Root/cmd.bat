REM Check: GPO Links on Domain Root
REM Category: Group Policy
REM Severity: info
REM ID: GPO-018
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=domainDNS)(gPLink=*))

dsquery * -filter "(&(objectClass=domainDNS)(gPLink=*))" -limit 0 -attr name distinguishedname gplink
