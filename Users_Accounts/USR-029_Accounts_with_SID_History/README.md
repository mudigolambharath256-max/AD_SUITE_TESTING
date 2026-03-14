# Accounts with SID History

## Description
Finds accounts with SIDHistory set (can be used for privilege escalation).

## Severity
HIGH

## Category
Users & Accounts

## Remediation
Remove SIDHistory after migration is complete. It can be abused for privilege escalation.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/component-updates/active-directory-security-assessment

## MITRE ATT&CK
T1134.005


