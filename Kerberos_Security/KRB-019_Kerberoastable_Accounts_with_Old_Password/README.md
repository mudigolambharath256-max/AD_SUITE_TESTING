# Kerberoastable Accounts with Old Password

## Description
Finds SPN accounts with passwords older than 1 year.

## Severity
CRITICAL

## Category
Kerberos Security

## Remediation
Rotate service account passwords at least yearly. Use gMSA for automatic rotation.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/security/kerberos/kerberos-authentication-overview

## MITRE ATT&CK
T1558.003


