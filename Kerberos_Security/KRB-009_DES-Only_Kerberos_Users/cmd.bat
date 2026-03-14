REM Check: DES-Only Kerberos (Users)
REM Category: Kerberos Security
REM Severity: critical
REM ID: KRB-009
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(userAccountControl:1.2.840.113556.1.4.803:=2097152))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(userAccountControl:1.2.840.113556.1.4.803:=2097152))" -limit 0 -attr name distinguishedname samaccountname useraccountcontrol
