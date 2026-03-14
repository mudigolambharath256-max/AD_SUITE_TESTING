REM Check: AAD DC Administrators Group
REM Category: Azure AD Integration
REM Severity: high
REM ID: AAD-008
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=group)(cn=AAD DC Administrators))

dsquery * -filter "(&(objectCategory=group)(cn=AAD DC Administrators))" -limit 0 -attr name distinguishedname cn member
