REM Check: Downlevel Trust Accounts
REM Category: Trust Relationships
REM Severity: info
REM ID: TRST-022
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=2048))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=2048))" -limit 0 -attr name distinguishedname samaccountname useraccountcontrol pwdlastset
