REM Check: Azure AD Connect Accounts (AAD_*)
REM Category: Azure AD Integration
REM Severity: high
REM ID: AAD-002
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(samAccountName=AAD_*))

dsquery * -filter "(&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(samAccountName=AAD_*))" -limit 0 -attr name distinguishedname samaccountname userprincipalname memberof description
