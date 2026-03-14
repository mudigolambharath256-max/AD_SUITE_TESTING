REM Check: AppLocker GPO Check
REM Category: Group Policy
REM Severity: info
REM ID: GPO-021
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=groupPolicyContainer)(|(displayName=*applocker*)(displayName=*AppLocker*)(displayName=*application*control*)))

dsquery * -filter "(&(objectClass=groupPolicyContainer)(|(displayName=*applocker*)(displayName=*AppLocker*)(displayName=*application*control*)))" -limit 0 -attr name distinguishedname displayname gpcfilesyspath
