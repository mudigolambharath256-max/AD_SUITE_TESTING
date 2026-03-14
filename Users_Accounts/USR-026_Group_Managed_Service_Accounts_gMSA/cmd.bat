REM Check: Group Managed Service Accounts (gMSA)
REM Category: Users & Accounts
REM Severity: info
REM ID: USR-026
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=msDS-GroupManagedServiceAccount)

dsquery * -filter "(objectClass=msDS-GroupManagedServiceAccount)" -limit 0 -attr name distinguishedname samaccountname msds-managedpasswordinterval msds-hostserviceaccount serviceprincipalname
