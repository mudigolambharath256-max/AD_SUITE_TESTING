# DC-044: DCs with Excessive Open Ports

## Description

Identifies Domain Controllers with non-standard ports open that may increase attack surface.

## Severity

**MEDIUM**

## Category

Domain Controllers

## What This Check Does

This check examines each Domain Controller for:
Netstat output analysis for non-standard listening ports

## Risk

Excessive open ports increase attack surface and may indicate unauthorized services or misconfigurations.

## Remediation

Review open ports, close unnecessary services, configure Windows Firewall to restrict access.

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
