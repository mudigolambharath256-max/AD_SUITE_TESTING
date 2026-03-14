REM Check: Hybrid Identity Security Summary
REM Category: Azure AD Integration
REM Severity: info
REM ID: AAD-030
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(|(samAccountName=MSOL_*)(samAccountName=AAD_*)(samAccountName=*sync*)(description=*Azure*)))

dsquery * -filter "(&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(|(samAccountName=MSOL_*)(samAccountName=AAD_*)(samAccountName=*sync*)(description=*Azure*)))" -limit 0 -attr name distinguishedname samaccountname userprincipalname description memberof pwdlastset
