REM Check: Credential Guard GPO Check
REM Category: Group Policy
REM Severity: info
REM ID: GPO-020
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=groupPolicyContainer)(|(displayName=*credential*)(displayName=*guard*)))

dsquery * -filter "(&(objectClass=groupPolicyContainer)(|(displayName=*credential*)(displayName=*guard*)))" -limit 0 -attr name distinguishedname displayname gpcfilesyspath
