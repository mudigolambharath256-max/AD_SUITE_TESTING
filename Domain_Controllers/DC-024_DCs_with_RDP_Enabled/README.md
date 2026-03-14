# DCs with RDP Enabled

## Description
Identifies DCs with Remote Desktop Protocol enabled. RDP on DCs increases attack surface.

## Severity
HIGH

## Category
Domain Controllers

## Remediation
Disable RDP on DCs. Use alternative management methods like PowerShell remoting or Server Manager.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/get-started/virtual-dc/active-directory-domain-services-overview

## MITRE ATT&CK
T1021.001



