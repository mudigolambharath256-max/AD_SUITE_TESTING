REM Check: sMSA Accounts (Legacy)
REM Category: Kerberos Security
REM Severity: info
REM ID: KRB-018
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=msDS-ManagedServiceAccount)

dsquery * -filter "(objectClass=msDS-ManagedServiceAccount)" -limit 0 -attr name distinguishedname samaccountname msds-managedpasswordinterval
