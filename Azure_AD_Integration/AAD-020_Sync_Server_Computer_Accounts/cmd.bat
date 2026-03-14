REM Check: Sync Server Computer Accounts
REM Category: Azure AD Integration
REM Severity: high
REM ID: AAD-020
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(|(cn=*AADConnect*)(cn=*AADC*)(description=*Azure AD Connect*)))

dsquery * -filter "(&(objectCategory=computer)(|(cn=*AADConnect*)(cn=*AADC*)(description=*Azure AD Connect*)))" -limit 0 -attr name distinguishedname samaccountname dnshostname operatingsystem description
