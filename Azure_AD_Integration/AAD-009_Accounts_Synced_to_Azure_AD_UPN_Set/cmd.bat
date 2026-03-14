REM Check: Accounts Synced to Azure AD (UPN Set)
REM Category: Azure AD Integration
REM Severity: info
REM ID: AAD-009
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(userPrincipalName=*))

dsquery * -filter "(&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(userPrincipalName=*))" -limit 0 -attr name distinguishedname samaccountname userprincipalname mail
