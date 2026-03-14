REM Check: Accounts with msDS-HostServiceAccount
REM Category: Users & Accounts
REM Severity: info
REM ID: USR-011
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=msDS-GroupManagedServiceAccount)(msDS-HostServiceAccount=*))

dsquery * -filter "(&(objectClass=msDS-GroupManagedServiceAccount)(msDS-HostServiceAccount=*))" -limit 0 -attr name distinguishedname samaccountname msds-hostserviceaccount msds-managedpasswordinterval
