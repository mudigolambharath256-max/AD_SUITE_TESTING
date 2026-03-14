# DCs with Disabled Windows Firewall

## Description
Checks if Windows Firewall is disabled on DCs. Firewall provides network-level protection.

## Severity
CRITICAL

## Category
Domain Controllers

## Remediation
Enable Windows Firewall on all profiles (Domain, Private, Public). Configure appropriate rules.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/get-started/virtual-dc/active-directory-domain-services-overview

## MITRE ATT&CK
T1562.004



