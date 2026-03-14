# Accounts with KeyCredentialLink (Shadow Credentials)

## Description
Finds accounts with msDS-KeyCredentialLink set (potential shadow credentials attack).

## Severity
HIGH

## Category
Users & Accounts

## Remediation
Validate all KeyCredentialLink entries are legitimate (WHfB/device registration). Remove unknown entries.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/component-updates/active-directory-security-assessment

## MITRE ATT&CK
T1098


