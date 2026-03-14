REM Check: Admin Accounts That Can Be Delegated
REM Category: Users & Accounts
REM Severity: high
REM ID: USR-005
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(adminCount=1)(!(userAccountControl:1.2.840.113556.1.4.803:=1048576)))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(adminCount=1)(!(userAccountControl:1.2.840.113556.1.4.803:=1048576)))" -limit 0 -attr name distinguishedname samaccountname useraccountcontrol
