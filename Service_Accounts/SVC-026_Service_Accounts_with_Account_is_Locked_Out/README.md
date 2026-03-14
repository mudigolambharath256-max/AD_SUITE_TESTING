# Service Accounts with “Account is Locked Out”

## Description
Lists SPN accounts with lockoutTime set (availability risk).

## Severity
LOW

## Category
Service Accounts

## Remediation
Investigate lockouts (possible password spraying). Fix service password sync and monitor auth logs.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/service-accounts/service-accounts

## MITRE ATT&CK
T1110


