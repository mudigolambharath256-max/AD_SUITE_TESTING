# Trusts Without SID Filtering

## Description
Finds trusts where SID filtering may be disabled (TRUST_ATTRIBUTE_TREAT_AS_EXTERNAL).

## Severity
CRITICAL

## Category
Trust Relationships

## Remediation
Enable SID filtering: netdom trust /quarantine:yes

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/entra/identity/domain-services/concepts-forest-trust
- https://adsecurity.org/?p=1640

## MITRE ATT&CK
T1134.005


