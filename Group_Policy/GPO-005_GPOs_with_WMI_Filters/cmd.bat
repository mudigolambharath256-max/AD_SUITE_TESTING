REM Check: GPOs with WMI Filters
REM Category: Group Policy
REM Severity: low
REM ID: GPO-005
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=groupPolicyContainer)(gPCWQLFilter=*))

dsquery * -filter "(&(objectClass=groupPolicyContainer)(gPCWQLFilter=*))" -limit 0 -attr name distinguishedname displayname gpcwqlfilter
