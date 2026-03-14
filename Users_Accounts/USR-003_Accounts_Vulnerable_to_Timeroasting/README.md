# Accounts Vulnerable to Timeroasting

## Description
Finds computer accounts with userPassword attribute set (non-standard, can be used for timing attacks).

## Severity
HIGH

## Category
Users & Accounts

## Remediation
Remove userPassword attribute from computer accounts. Use proper machine authentication.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/component-updates/active-directory-security-assessment

## MITRE ATT&CK
T1110


