REM Check: Service Accounts Advertising DES Support (msDS-SupportedEncryptionTypes)
REM Category: Service Accounts
REM Severity: critical
REM ID: SVC-005
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(msDS-SupportedEncryptionTypes:1.2.840.113556.1.4.803:=3))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(msDS-SupportedEncryptionTypes:1.2.840.113556.1.4.803:=3))" -limit 0 -attr name distinguishedname samaccountname msds-supportedencryptiontypes serviceprincipalname
