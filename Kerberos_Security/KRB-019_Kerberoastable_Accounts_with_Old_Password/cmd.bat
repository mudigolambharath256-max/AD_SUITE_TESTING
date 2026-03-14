REM Check: Kerberoastable Accounts with Old Password
REM Category: Kerberos Security
REM Severity: critical
REM ID: KRB-019
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(servicePrincipalName=*))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(servicePrincipalName=*))" -limit 0 -attr name distinguishedname samaccountname serviceprincipalname pwdlastset
