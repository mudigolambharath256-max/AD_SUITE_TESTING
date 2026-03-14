REM Check: Audit Policy GPO Check
REM Category: Group Policy
REM Severity: info
REM ID: GPO-024
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=groupPolicyContainer)(|(displayName=*audit*)(displayName=*Audit*)(displayName=*logging*)))

dsquery * -filter "(&(objectClass=groupPolicyContainer)(|(displayName=*audit*)(displayName=*Audit*)(displayName=*logging*)))" -limit 0 -attr name distinguishedname displayname gpcfilesyspath
