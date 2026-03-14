# DC-051: DCs with Excessive Service Accounts

## Description

Identifies Domain Controllers with services running under domain accounts, which increases credential exposure risk.

## Severity

**HIGH**

## Category

Domain Controllers

## What This Check Does

This check examines each Domain Controller for:
Service enumeration checking for services running under domain accounts

## Risk

Credential exposure, privilege escalation, lateral movement if service account compromised.

## Remediation

Use Group Managed Service Accounts (gMSA), Local System, or Network Service where possible.

## Best Practices

1. Regularly audit Domain Controller configurations
2. Implement least privilege principles
3. Monitor for configuration drift
4. Document approved exceptions
5. Test changes in non-production first

## References

- [Microsoft Security Baselines](https://learn.microsoft.com/en-us/windows/security/threat-protection/windows-security-baselines)
- [CIS Benchmarks for Windows Server](https://www.cisecurity.org/benchmark/microsoft_windows_server)

## Output

Returns Domain Controllers with issues:
- DC Name
- DNS Hostname
- Issue Description
- Current Configuration
- Recommended Action
