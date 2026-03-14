REM Check: Templates Without Authorized Signatures Required
REM Category: Certificate Services
REM Severity: medium
REM ID: CERT-011
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=pKICertificateTemplate)(|(msPKI-RA-Signature=0)(!(msPKI-RA-Signature=*))))

dsquery * -filter "(&(objectClass=pKICertificateTemplate)(|(msPKI-RA-Signature=0)(!(msPKI-RA-Signature=*))))" -limit 0 -attr name distinguishedname cn displayname mspki-ra-signature
