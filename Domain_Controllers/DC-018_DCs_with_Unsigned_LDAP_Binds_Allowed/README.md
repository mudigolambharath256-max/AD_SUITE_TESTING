# DCs with Unsigned LDAP Binds Allowed

## Description
Checks if DCs allow unsigned LDAP binds (LDAPServerIntegrity=0). This allows unencrypted LDAP traffic.

## Severity
HIGH

## Category
Domain Controllers

## Remediation
Set LDAPServerIntegrity to at least 1 (Negotiate signing) or 2 (Require signing).

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/get-started/virtual-dc/active-directory-domain-services-overview

## MITRE ATT&CK
T1557.001



