REM Check: Service Accounts Missing AES256 Support (Inventory)
REM Category: Service Accounts
REM Severity: medium
REM ID: SVC-030
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(!(msDS-SupportedEncryptionTypes:1.2.840.113556.1.4.803:=16)))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(!(msDS-SupportedEncryptionTypes:1.2.840.113556.1.4.803:=16)))" -limit 0 -attr name distinguishedname samaccountname msds-supportedencryptiontypes serviceprincipalname
