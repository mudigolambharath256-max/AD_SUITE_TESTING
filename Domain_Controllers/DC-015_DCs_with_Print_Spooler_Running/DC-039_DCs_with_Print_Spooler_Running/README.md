# DCs with Print Spooler Running

## Description
Identifies Domain Controllers with Print Spooler service running. Print Spooler on DCs enables PrintNightmare and other relay attacks and should be disabled.

## Severity
CRITICAL

## Category
Domain Controllers

## Remediation
Disable Print Spooler service on all Domain Controllers via Group Policy or manually. DCs do not need print services and this reduces attack surface significantly.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/get-started/virtual-dc/active-directory-domain-services-overview

## MITRE ATT&CK
T1068



