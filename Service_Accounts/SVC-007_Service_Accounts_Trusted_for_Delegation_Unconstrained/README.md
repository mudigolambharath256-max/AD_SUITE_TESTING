# Service Accounts Trusted for Delegation (Unconstrained)

## Description
Finds SPN accounts with TRUSTED_FOR_DELEGATION set (very sensitive).

## Severity
CRITICAL

## Category
Service Accounts

## Remediation
Remove unconstrained delegation from service accounts. Use constrained delegation/RBCD.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/service-accounts/service-accounts

## MITRE ATT&CK
T1558


