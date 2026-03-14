REM Check: Seamless SSO Computer Account (AZUREADSSOACC)
REM Category: Azure AD Integration
REM Severity: high
REM ID: AAD-003
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(samAccountName=AZUREADSSOACC$))

dsquery * -filter "(&(objectCategory=computer)(samAccountName=AZUREADSSOACC$))" -limit 0 -attr name distinguishedname samaccountname pwdlastset useraccountcontrol
