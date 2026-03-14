REM Check: Constrained Delegation (Users)
REM Category: Kerberos Security
REM Severity: high
REM ID: KRB-006
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(msDS-AllowedToDelegateTo=*))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(msDS-AllowedToDelegateTo=*))" -limit 0 -attr name distinguishedname samaccountname msds-allowedtodelegateto
