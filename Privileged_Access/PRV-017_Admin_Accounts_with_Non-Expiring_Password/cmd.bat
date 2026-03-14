REM Check: Admin Accounts with Non-Expiring Password
REM Category: Privileged Access
REM Severity: critical
REM ID: PRV-017
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(adminCount=1)(userAccountControl:1.2.840.113556.1.4.803:=65536))

dsquery * -filter "(&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(adminCount=1)(userAccountControl:1.2.840.113556.1.4.803:=65536))" -limit 0 -attr name distinguishedname samaccountname useraccountcontrol pwdlastset
