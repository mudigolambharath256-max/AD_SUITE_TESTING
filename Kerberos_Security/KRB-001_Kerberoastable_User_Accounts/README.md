# Kerberoastable User Accounts

## Description
Lists user accounts with SPNs set. These can be targeted for Kerberoasting attacks.

## Severity
HIGH

## Category
Kerberos Security

## Remediation
Use gMSAs. If not possible, use 25+ char passwords and rotate every 30 days. Monitor Event 4769.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/security/kerberos/kerberos-authentication-overview

## MITRE ATT&CK
T1558.003


