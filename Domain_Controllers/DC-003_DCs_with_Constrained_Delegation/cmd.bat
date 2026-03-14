
@echo off
REM Check: DCs with Constrained Delegation
REM Category: Domain Controllers
REM Severity: medium
REM ID: DC-003
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192)(msDS-AllowedToDelegateTo=*))

dsquery * -filter "(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192)(msDS-AllowedToDelegateTo=*))" -limit 0 -attr name distinguishedname samaccountname msds-allowedtodelegateto
