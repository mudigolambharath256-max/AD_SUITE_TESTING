# Writeback Enabled Indicators

## Description
Identifies accounts that may indicate password writeback.

## Severity
HIGH

## Category
Azure AD Integration

## Remediation
Password writeback requires DCSync rights. Ensure sync account is protected.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/entra/identity/hybrid/connect/whatis-azure-ad-connect
- https://aadinternals.com/

## MITRE ATT&CK
T1003.006


