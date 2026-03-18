REM Check: Computers with Managed Password (gMSA Hosts)
REM Category: Computers & Servers
REM Severity: info
REM ID: CMP-030
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=msDS-GroupManagedServiceAccount)(msDS-HostServiceAccount=*))

dsquery * -filter "(&(objectClass=msDS-GroupManagedServiceAccount)(msDS-HostServiceAccount=*))" -limit 0 -attr name distinguishedname samaccountname msds-hostserviceaccount
