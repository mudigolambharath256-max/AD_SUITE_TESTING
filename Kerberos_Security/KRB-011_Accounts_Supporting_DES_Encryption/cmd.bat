REM Check: Accounts Supporting DES Encryption
REM Category: Kerberos Security
REM Severity: high
REM ID: KRB-011
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(!(userAccountControl:1.2.840.113556.1.4.803:=2))(msDS-SupportedEncryptionTypes:1.2.840.113556.1.4.803:=3))

dsquery * -filter "(&(!(userAccountControl:1.2.840.113556.1.4.803:=2))(msDS-SupportedEncryptionTypes:1.2.840.113556.1.4.803:=3))" -limit 0 -attr name distinguishedname samaccountname msds-supportedencryptiontypes
