REM Check: gMSA Accounts
REM Category: Kerberos Security
REM Severity: info
REM ID: KRB-017
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=msDS-GroupManagedServiceAccount)

dsquery * -filter "(objectClass=msDS-GroupManagedServiceAccount)" -limit 0 -attr name distinguishedname samaccountname msds-managedpasswordinterval msds-hostserviceaccount serviceprincipalname
