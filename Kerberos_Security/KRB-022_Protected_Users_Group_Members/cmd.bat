REM Check: Protected Users Group Members
REM Category: Kerberos Security
REM Severity: info
REM ID: KRB-022
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(memberOf:1.2.840.113556.1.4.1941:=CN=Protected Users,CN=Users,*))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(memberOf:1.2.840.113556.1.4.1941:=CN=Protected Users,CN=Users,*))" -limit 0 -attr name distinguishedname samaccountname memberof
