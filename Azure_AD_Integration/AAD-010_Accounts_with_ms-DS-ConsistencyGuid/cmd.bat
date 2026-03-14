REM Check: Accounts with ms-DS-ConsistencyGuid
REM Category: Azure AD Integration
REM Severity: info
REM ID: AAD-010
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(ms-DS-ConsistencyGuid=*))

dsquery * -filter "(&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(ms-DS-ConsistencyGuid=*))" -limit 0 -attr name distinguishedname samaccountname ms-ds-consistencyguid userprincipalname
