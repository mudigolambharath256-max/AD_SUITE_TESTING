REM Check: Admin Accounts with SPNs (Kerberoasting Risk)
REM Category: Privileged Access
REM Severity: critical
REM ID: PRV-018
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(adminCount=1)(servicePrincipalName=*))

dsquery * -filter "(&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(adminCount=1)(servicePrincipalName=*))" -limit 0 -attr name distinguishedname samaccountname serviceprincipalname pwdlastset
