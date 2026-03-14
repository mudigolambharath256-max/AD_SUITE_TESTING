REM Check: Accounts with altSecurityIdentities
REM Category: Users & Accounts
REM Severity: medium
REM ID: USR-007
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(altSecurityIdentities=*))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(altSecurityIdentities=*))" -limit 0 -attr name distinguishedname samaccountname altsecurityidentities
