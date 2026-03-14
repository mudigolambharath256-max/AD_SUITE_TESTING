REM Check: GPO Containing Password (Naming)
REM Category: Group Policy
REM Severity: high
REM ID: GPO-006
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=groupPolicyContainer)(|(displayName=*password*)(displayName=*Password*)(displayName=*PASSWORD*)))

dsquery * -filter "(&(objectClass=groupPolicyContainer)(|(displayName=*password*)(displayName=*Password*)(displayName=*PASSWORD*)))" -limit 0 -attr name distinguishedname displayname gpcfilesyspath
