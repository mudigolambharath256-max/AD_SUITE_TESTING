REM Check: Accounts with ExtensionAttributes (Exchange)
REM Category: Azure AD Integration
REM Severity: info
REM ID: AAD-029
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(|(extensionAttribute1=*)(extensionAttribute2=*)(extensionAttribute15=*)))

dsquery * -filter "(&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(|(extensionAttribute1=*)(extensionAttribute2=*)(extensionAttribute15=*)))" -limit 0 -attr name distinguishedname samaccountname extensionattribute1 extensionattribute15
