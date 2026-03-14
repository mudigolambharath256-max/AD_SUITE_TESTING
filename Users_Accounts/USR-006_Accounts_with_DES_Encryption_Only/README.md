# Accounts with DES Encryption Only

## Description
Finds accounts configured to use only DES encryption (weak, easily cracked).

## Severity
CRITICAL

## Category
Users & Accounts

## Remediation
Disable "Use Kerberos DES encryption types" and reset the password to generate new keys.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/component-updates/active-directory-security-assessment

## MITRE ATT&CK
T1558.003


