REM Check: PowerShell Logging GPO Check
REM Category: Group Policy
REM Severity: info
REM ID: GPO-026
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=groupPolicyContainer)(|(displayName=*powershell*)(displayName=*PowerShell*)(displayName=*script*)))

dsquery * -filter "(&(objectClass=groupPolicyContainer)(|(displayName=*powershell*)(displayName=*PowerShell*)(displayName=*script*)))" -limit 0 -attr name distinguishedname displayname gpcfilesyspath
