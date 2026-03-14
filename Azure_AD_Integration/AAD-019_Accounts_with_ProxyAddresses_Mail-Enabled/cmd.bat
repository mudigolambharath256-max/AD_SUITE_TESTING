REM Check: Accounts with ProxyAddresses (Mail-Enabled)
REM Category: Azure AD Integration
REM Severity: info
REM ID: AAD-019
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(proxyAddresses=*))

dsquery * -filter "(&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(proxyAddresses=*))" -limit 0 -attr name distinguishedname samaccountname proxyaddresses mail
