# Service Accounts Marked adminCount=1

## Description
Finds SPN accounts protected by AdminSDHolder (adminCount=1).

## Severity
HIGH

## Category
Service Accounts

## Remediation
Review privileged service accounts. Remove unnecessary admin memberships and adopt gMSA.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/service-accounts/service-accounts

## MITRE ATT&CK
T1078


