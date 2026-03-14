# DCs with Old DSRM Password

## Description
Checks Directory Services Restore Mode password age. DSRM password should be changed regularly.

## Severity
CRITICAL

## Category
Domain Controllers

## Remediation
Change DSRM password regularly (at least annually) using ntdsutil. Document password securely.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/get-started/virtual-dc/active-directory-domain-services-overview

## MITRE ATT&CK
T1003.003



