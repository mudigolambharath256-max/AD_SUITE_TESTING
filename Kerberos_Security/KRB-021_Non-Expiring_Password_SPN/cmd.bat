REM Check: Non-Expiring Password + SPN
REM Category: Kerberos Security
REM Severity: high
REM ID: KRB-021
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(servicePrincipalName=*)(userAccountControl:1.2.840.113556.1.4.803:=65536))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(servicePrincipalName=*)(userAccountControl:1.2.840.113556.1.4.803:=65536))" -limit 0 -attr name distinguishedname samaccountname serviceprincipalname pwdlastset
