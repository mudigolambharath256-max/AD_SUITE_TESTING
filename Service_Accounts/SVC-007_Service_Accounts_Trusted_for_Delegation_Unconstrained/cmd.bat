REM Check: Service Accounts Trusted for Delegation (Unconstrained)
REM Category: Service Accounts
REM Severity: critical
REM ID: SVC-007
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(userAccountControl:1.2.840.113556.1.4.803:=524288))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(userAccountControl:1.2.840.113556.1.4.803:=524288))" -limit 0 -attr name distinguishedname samaccountname useraccountcontrol serviceprincipalname
