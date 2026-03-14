REM Check: Admin Accounts with DES Encryption
REM Category: Privileged Access
REM Severity: critical
REM ID: PRV-030
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(adminCount=1)(userAccountControl:1.2.840.113556.1.4.803:=2097152))

dsquery * -filter "(&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(adminCount=1)(userAccountControl:1.2.840.113556.1.4.803:=2097152))" -limit 0 -attr name distinguishedname samaccountname useraccountcontrol
