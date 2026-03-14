REM Check: Sensitive Accounts Without AES
REM Category: Kerberos Security
REM Severity: high
REM ID: KRB-027
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(adminCount=1)(!(msDS-SupportedEncryptionTypes:1.2.840.113556.1.4.803:=24)))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(adminCount=1)(!(msDS-SupportedEncryptionTypes:1.2.840.113556.1.4.803:=24)))" -limit 0 -attr name distinguishedname samaccountname msds-supportedencryptiontypes
