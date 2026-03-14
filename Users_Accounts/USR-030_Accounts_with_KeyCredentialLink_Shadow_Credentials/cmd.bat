REM Check: Accounts with KeyCredentialLink (Shadow Credentials)
REM Category: Users & Accounts
REM Severity: high
REM ID: USR-030
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(msDS-KeyCredentialLink=*))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(msDS-KeyCredentialLink=*))" -limit 0 -attr name distinguishedname samaccountname msds-keycredentiallink
