REM Check: Accounts with Azure AD Device Registration
REM Category: Azure AD Integration
REM Severity: info
REM ID: AAD-025
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(msDS-RegisteredOwner=*))

dsquery * -filter "(&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(msDS-RegisteredOwner=*))" -limit 0 -attr name distinguishedname samaccountname msds-registeredowner
