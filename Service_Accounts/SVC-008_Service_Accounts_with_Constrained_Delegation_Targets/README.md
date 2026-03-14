# Service Accounts with Constrained Delegation Targets

## Description
Finds SPN accounts with msDS-AllowedToDelegateTo set (constrained delegation).

## Severity
HIGH

## Category
Service Accounts

## Remediation
Reduce delegation targets and monitor ticket usage. Prefer RBCD where suitable.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/service-accounts/service-accounts

## MITRE ATT&CK
T1558


