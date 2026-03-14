# DCs Null Session Enabled

## Description
Checks if Domain Controllers allow null session connections. Null sessions allow anonymous enumeration of domain information and should be disabled.

## Severity
CRITICAL

## Category
Domain Controllers

## Remediation
Disable null sessions via Group Policy: "Network access: Do not allow anonymous enumeration of SAM accounts and shares" and "Network access: Restrict anonymous access to Named Pipes and Shares".

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/get-started/virtual-dc/active-directory-domain-services-overview

## MITRE ATT&CK
T1087.002



