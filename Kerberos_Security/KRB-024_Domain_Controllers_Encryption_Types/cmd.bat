REM Check: Domain Controllers Encryption Types
REM Category: Kerberos Security
REM Severity: info
REM ID: KRB-024
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))

dsquery * -filter "(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))" -limit 0 -attr name distinguishedname samaccountname msds-supportedencryptiontypes dnshostname
