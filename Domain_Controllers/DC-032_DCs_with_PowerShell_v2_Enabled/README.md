# DCs with PowerShell v2 Enabled

## Description
Checks if PowerShell 2.0 is installed. PS v2 bypasses modern security features like logging and AMSI.

## Severity
HIGH

## Category
Domain Controllers

## Remediation
Remove PowerShell 2.0 feature using: Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2Root

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/get-started/virtual-dc/active-directory-domain-services-overview

## MITRE ATT&CK
T1059.001



