@echo off
REM Check: FSMO Role Holders
REM Category: Domain Controllers
REM Severity: info
REM ID: DC-007
REM Requirements: dsquery (RSAT DS tools)
REM ============================================
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=domainDNS)

REM PDC Emulator + RIDManagerReference from domain root
dsquery * -filter "(objectClass=domainDNS)" -limit 0 -attr name distinguishedname fsmoroleowner ridmanagerreference

REM Infrastructure Master from CN=Infrastructure
echo --- Infrastructure Master ---
dsquery * "CN=Infrastructure,DC=Mahishmati,DC=org" -scope base -filter "(objectClass=infrastructureUpdate)" -limit 0 -attr fsmoroleowner