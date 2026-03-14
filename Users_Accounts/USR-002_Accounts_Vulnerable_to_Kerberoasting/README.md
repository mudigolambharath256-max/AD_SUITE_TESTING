# Accounts Vulnerable to Kerberoasting

## Description
Finds user accounts with SPNs set. Attackers can request service tickets and crack them offline.

## Severity
HIGH

## Category
Users & Accounts

## Remediation
Migrate to gMSA accounts. If not possible, use 25+ char passwords and rotate every 30 days. Monitor for Kerberoasting (4769 events with encryption type 0x17).

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/component-updates/active-directory-security-assessment

## MITRE ATT&CK
T1558.003


