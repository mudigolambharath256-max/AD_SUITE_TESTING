REM Check: Service Principals with Azure in Name
REM Category: Azure AD Integration
REM Severity: info
REM ID: AAD-021
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(servicePrincipalName=*azure*))

dsquery * -filter "(&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(servicePrincipalName=*azure*))" -limit 0 -attr name distinguishedname samaccountname serviceprincipalname
