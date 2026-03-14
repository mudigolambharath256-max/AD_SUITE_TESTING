# Accounts with Never Expiring Passwords

## Description
Finds accounts with DONT_EXPIRE_PASSWORD flag set.

## Severity
HIGH

## Category
Users & Accounts

## Remediation
Remove non-expiring password flag and enforce password policy. Exception: service accounts should use gMSA.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/component-updates/active-directory-security-assessment

## MITRE ATT&CK
T1078


