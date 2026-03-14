REM Check: LAPS GPO Check
REM Category: Group Policy
REM Severity: info
REM ID: GPO-023
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=groupPolicyContainer)(|(displayName=*laps*)(displayName=*LAPS*)(displayName=*local*admin*)))

dsquery * -filter "(&(objectClass=groupPolicyContainer)(|(displayName=*laps*)(displayName=*LAPS*)(displayName=*local*admin*)))" -limit 0 -attr name distinguishedname displayname gpcfilesyspath
