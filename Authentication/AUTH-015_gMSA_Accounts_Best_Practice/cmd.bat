REM Check: gMSA Accounts (Best Practice)
REM Category: Authentication
REM Severity: info
REM ID: AUTH-015
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=msDS-GroupManagedServiceAccount)

dsquery * -filter "(objectClass=msDS-GroupManagedServiceAccount)" -limit 0 -attr name distinguishedname samaccountname msds-managedpasswordinterval msds-hostserviceaccount
