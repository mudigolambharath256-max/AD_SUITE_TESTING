REM Check: Firewall GPO Check
REM Category: Group Policy
REM Severity: info
REM ID: GPO-025
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=groupPolicyContainer)(|(displayName=*firewall*)(displayName=*Firewall*)))

dsquery * -filter "(&(objectClass=groupPolicyContainer)(|(displayName=*firewall*)(displayName=*Firewall*)))" -limit 0 -attr name distinguishedname displayname gpcfilesyspath
