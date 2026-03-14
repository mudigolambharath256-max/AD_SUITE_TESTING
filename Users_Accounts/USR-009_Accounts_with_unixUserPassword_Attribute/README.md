# Accounts with unixUserPassword Attribute

## Description
Finds accounts with unixUserPassword attribute set (Unix integration, may be weak hash).

## Severity
HIGH

## Category
Users & Accounts

## Remediation
Remove unixUserPassword or ensure strong hashing. Consider using SSSD with Kerberos instead.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/component-updates/active-directory-security-assessment

## MITRE ATT&CK
T1552.006


