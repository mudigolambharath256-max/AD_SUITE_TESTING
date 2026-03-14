REM Check: GPOs Missing SYSVOL Path
REM Category: Group Policy
REM Severity: high
REM ID: GPO-004
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=groupPolicyContainer)(!(gPCFileSysPath=*)))

dsquery * -filter "(&(objectClass=groupPolicyContainer)(!(gPCFileSysPath=*)))" -limit 0 -attr name distinguishedname displayname
