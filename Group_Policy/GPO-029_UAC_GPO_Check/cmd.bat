REM Check: UAC GPO Check
REM Category: Group Policy
REM Severity: info
REM ID: GPO-029
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=groupPolicyContainer)(|(displayName=*uac*)(displayName=*UAC*)(displayName=*user*account*control*)))

dsquery * -filter "(&(objectClass=groupPolicyContainer)(|(displayName=*uac*)(displayName=*UAC*)(displayName=*user*account*control*)))" -limit 0 -attr name distinguishedname displayname gpcfilesyspath
