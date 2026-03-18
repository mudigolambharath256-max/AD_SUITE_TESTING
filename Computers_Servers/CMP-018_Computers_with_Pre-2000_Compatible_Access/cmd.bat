REM Check: Computers with Pre-2000 Compatible Access
REM Category: Computers & Servers
REM Severity: medium
REM ID: CMP-018
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(memberOf:1.2.840.113556.1.4.1941:=CN=Pre-Windows 2000 Compatible Access,CN=Builtin,*))

dsquery * -filter "(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(memberOf:1.2.840.113556.1.4.1941:=CN=Pre-Windows 2000 Compatible Access,CN=Builtin,*))" -limit 0 -attr name distinguishedname samaccountname memberof
