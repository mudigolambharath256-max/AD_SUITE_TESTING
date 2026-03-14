REM Check: Service Accounts Missing msDS-SupportedEncryptionTypes
REM Category: Service Accounts
REM Severity: medium
REM ID: SVC-006
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(!(msDS-SupportedEncryptionTypes=*)))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(!(msDS-SupportedEncryptionTypes=*)))" -limit 0 -attr name distinguishedname samaccountname serviceprincipalname
