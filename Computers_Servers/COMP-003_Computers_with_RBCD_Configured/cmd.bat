REM Check: Computers with RBCD Configured
REM Category: Computers & Servers
REM Severity: high
REM ID: COMP-003
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(msDS-AllowedToActOnBehalfOfOtherIdentity=*))

dsquery * -filter "(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(msDS-AllowedToActOnBehalfOfOtherIdentity=*))" -limit 0 -attr name distinguishedname samaccountname msds-allowedtoactonbehalfofotheridentity
