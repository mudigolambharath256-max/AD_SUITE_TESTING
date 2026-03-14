REM Check: BitLocker GPO Check
REM Category: Group Policy
REM Severity: info
REM ID: GPO-022
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=groupPolicyContainer)(|(displayName=*bitlocker*)(displayName=*BitLocker*)(displayName=*encryption*)))

dsquery * -filter "(&(objectClass=groupPolicyContainer)(|(displayName=*bitlocker*)(displayName=*BitLocker*)(displayName=*encryption*)))" -limit 0 -attr name distinguishedname displayname gpcfilesyspath
