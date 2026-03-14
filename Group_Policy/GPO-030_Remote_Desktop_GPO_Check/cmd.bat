REM Check: Remote Desktop GPO Check
REM Category: Group Policy
REM Severity: info
REM ID: GPO-030
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=groupPolicyContainer)(|(displayName=*rdp*)(displayName=*RDP*)(displayName=*remote*desktop*)))

dsquery * -filter "(&(objectClass=groupPolicyContainer)(|(displayName=*rdp*)(displayName=*RDP*)(displayName=*remote*desktop*)))" -limit 0 -attr name distinguishedname displayname gpcfilesyspath
