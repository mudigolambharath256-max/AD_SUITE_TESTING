REM Check: Security Baseline GPO Check
REM Category: Group Policy
REM Severity: info
REM ID: GPO-027
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=groupPolicyContainer)(|(displayName=*baseline*)(displayName=*Baseline*)(displayName=*security*)(displayName=*hardening*)))

dsquery * -filter "(&(objectClass=groupPolicyContainer)(|(displayName=*baseline*)(displayName=*Baseline*)(displayName=*security*)(displayName=*hardening*)))" -limit 0 -attr name distinguishedname displayname gpcfilesyspath
