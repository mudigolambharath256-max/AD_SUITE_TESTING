# SPN Accounts with “Do not require Kerberos preauth” + Non-expiring password

## Description
High risk combination for cracking/persistence.

## Severity
CRITICAL

## Category
Service Accounts

## Remediation
Enable preauth, enforce rotation, and migrate to gMSA where possible.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/service-accounts/service-accounts

## MITRE ATT&CK
T1558.003


