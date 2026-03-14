# Admin Accounts Not in Protected Users Group

## Description
Finds privileged accounts (adminCount=1) not in the Protected Users security group.

## Severity
HIGH

## Category
Users & Accounts

## Remediation
Add privileged accounts to the Protected Users group to prevent credential caching and NTLM downgrade.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/component-updates/active-directory-security-assessment

## MITRE ATT&CK
T1078.002


