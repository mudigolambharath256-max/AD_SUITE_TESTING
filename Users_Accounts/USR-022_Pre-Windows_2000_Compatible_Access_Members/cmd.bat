REM Check: Pre-Windows 2000 Compatible Access Members
REM Category: Users & Accounts
REM Severity: high
REM ID: USR-022
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=group)(cn=Pre-Windows 2000 Compatible Access))

dsquery * -filter "(&(objectCategory=group)(cn=Pre-Windows 2000 Compatible Access))" -limit 0 -attr name distinguishedname cn member
