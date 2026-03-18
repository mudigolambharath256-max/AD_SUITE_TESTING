REM Check: Computers Created in Last 7 Days
REM Category: Computers & Servers
REM Severity: info
REM ID: CMP-019
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))

dsquery * -filter "(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))" -limit 0 -attr name distinguishedname samaccountname whencreated operatingsystem
