REM Check: Accounts Without Explicit Encryption Types
REM Category: Kerberos Security
REM Severity: medium
REM ID: KRB-012
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(!(msDS-SupportedEncryptionTypes=*)))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(!(msDS-SupportedEncryptionTypes=*)))" -limit 0 -attr name distinguishedname samaccountname objectclass
