REM Check: Accounts with AES256 Only
REM Category: Kerberos Security
REM Severity: info
REM ID: KRB-023
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(!(userAccountControl:1.2.840.113556.1.4.803:=2))(msDS-SupportedEncryptionTypes=24))

dsquery * -filter "(&(!(userAccountControl:1.2.840.113556.1.4.803:=2))(msDS-SupportedEncryptionTypes=24))" -limit 0 -attr name distinguishedname samaccountname msds-supportedencryptiontypes
