REM Check: Computers with KeyCredentialLink
REM Category: Computers & Servers
REM Severity: medium
REM ID: CMP-010
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(msDS-KeyCredentialLink=*))

dsquery * -filter "(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(msDS-KeyCredentialLink=*))" -limit 0 -attr name distinguishedname samaccountname msds-keycredentiallink
