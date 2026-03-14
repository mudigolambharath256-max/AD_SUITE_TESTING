REM Check: WSUS GPO Check
REM Category: Group Policy
REM Severity: info
REM ID: GPO-028
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=groupPolicyContainer)(|(displayName=*wsus*)(displayName=*WSUS*)(displayName=*update*)(displayName=*Update*)))

dsquery * -filter "(&(objectClass=groupPolicyContainer)(|(displayName=*wsus*)(displayName=*WSUS*)(displayName=*update*)(displayName=*Update*)))" -limit 0 -attr name distinguishedname displayname gpcfilesyspath
