REM Check: Accounts Blocked from Sync
REM Category: Azure AD Integration
REM Severity: info
REM ID: AAD-022
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(isCriticalSystemObject=TRUE))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(isCriticalSystemObject=TRUE))" -limit 0 -attr name distinguishedname samaccountname iscriticalsystemobject
