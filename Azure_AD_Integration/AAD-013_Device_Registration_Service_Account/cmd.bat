REM Check: Device Registration Service Account
REM Category: Azure AD Integration
REM Severity: info
REM ID: AAD-013
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(|(samAccountName=*DeviceReg*)(description=*device registration*)))

dsquery * -filter "(&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(|(samAccountName=*DeviceReg*)(description=*device registration*)))" -limit 0 -attr name distinguishedname samaccountname description memberof
