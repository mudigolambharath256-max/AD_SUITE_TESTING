# DC-057: DCs with Insecure WMI Permissions

## Description

Identifies Domain Controllers with overly permissive WMI namespace security.

## Severity

**MEDIUM**

## Category

Domain Controllers

## What This Check Does

This check examines each Domain Controller for:
WMI namespace security descriptor analysis

## Risk

Unauthorized remote management, information disclosure, lateral movement.

## Remediation

Review and restrict WMI permissions, limit remote WMI access.

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
