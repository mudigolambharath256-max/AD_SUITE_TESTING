REM Check: Accounts with Account Expiration
REM Category: Authentication
REM Severity: info
REM ID: AUTH-027
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(accountExpires>=1)(!(accountExpires=9223372036854775807)))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(accountExpires>=1)(!(accountExpires=9223372036854775807)))" -limit 0 -attr name distinguishedname samaccountname accountexpires
