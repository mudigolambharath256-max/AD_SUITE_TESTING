# DC Accounts Not Protected

## Description
Identifies Domain Controller computer accounts that are not in protected OUs or lack AdminSDHolder protection. DC accounts should have additional security measures.

## Severity
HIGH

## Category
Domain Controllers

## Remediation
Ensure DC computer accounts are in the Domain Controllers OU. Verify AdminSDHolder is functioning correctly. Consider additional ACL hardening on DC objects.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/get-started/virtual-dc/active-directory-domain-services-overview

## MITRE ATT&CK
T1078.002



