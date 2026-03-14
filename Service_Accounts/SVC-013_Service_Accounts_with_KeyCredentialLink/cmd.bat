REM Check: Service Accounts with KeyCredentialLink
REM Category: Service Accounts
REM Severity: high
REM ID: SVC-013
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(msDS-KeyCredentialLink=*))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(msDS-KeyCredentialLink=*))" -limit 0 -attr name distinguishedname samaccountname msds-keycredentiallink serviceprincipalname
