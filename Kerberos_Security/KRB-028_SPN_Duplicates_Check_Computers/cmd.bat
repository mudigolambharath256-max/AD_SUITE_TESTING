REM Check: SPN Duplicates Check (Computers)
REM Category: Kerberos Security
REM Severity: info
REM ID: KRB-028
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(servicePrincipalName=*))

dsquery * -filter "(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(servicePrincipalName=*))" -limit 0 -attr name distinguishedname samaccountname serviceprincipalname
