# Accounts with userPassword Attribute

## Description
Finds accounts with legacy userPassword attribute (plaintext or reversible).

## Severity
CRITICAL

## Category
Users & Accounts

## Remediation
Remove userPassword attribute. This is a legacy attribute that may store credentials insecurely.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/component-updates/active-directory-security-assessment

## MITRE ATT&CK
T1552.006


