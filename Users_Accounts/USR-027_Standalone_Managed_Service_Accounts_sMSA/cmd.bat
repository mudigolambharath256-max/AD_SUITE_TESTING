REM Check: Standalone Managed Service Accounts (sMSA)
REM Category: Users & Accounts
REM Severity: info
REM ID: USR-027
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=msDS-ManagedServiceAccount)

dsquery * -filter "(objectClass=msDS-ManagedServiceAccount)" -limit 0 -attr name distinguishedname samaccountname msds-managedpasswordinterval
