REM Check: Azure AD Application Proxy Connectors
REM Category: Azure AD Integration
REM Severity: info
REM ID: AAD-027
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(|(description=*app proxy*)(description=*application proxy*)))

dsquery * -filter "(&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(|(description=*app proxy*)(description=*application proxy*)))" -limit 0 -attr name distinguishedname samaccountname description
