REM Check: Users in Privilege Escalation Groups
REM Category: Users & Accounts
REM Severity: high
REM ID: USR-023
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(|(memberOf:1.2.840.113556.1.4.1941:=CN=Backup Operators,CN=Builtin,*)(memberOf:1.2.840.113556.1.4.1941:=CN=Account Operators,CN=Builtin,*)(memberOf:1.2.840.113556.1.4.1941:=CN=Server Operators,CN=Builtin,*)(memberOf:1.2.840.113556.1.4.1941:=CN=Print Operators,CN=Builtin,*)))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(|(memberOf:1.2.840.113556.1.4.1941:=CN=Backup Operators,CN=Builtin,*)(memberOf:1.2.840.113556.1.4.1941:=CN=Account Operators,CN=Builtin,*)(memberOf:1.2.840.113556.1.4.1941:=CN=Server Operators,CN=Builtin,*)(memberOf:1.2.840.113556.1.4.1941:=CN=Print Operators,CN=Builtin,*)))" -limit 0 -attr name distinguishedname samaccountname memberof
