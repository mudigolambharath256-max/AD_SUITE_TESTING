# DC-055: DCs with Unsigned Drivers Allowed

## Description

Identifies Domain Controllers that allow installation of unsigned drivers.

## Severity

**HIGH**

## Category

Domain Controllers

## What This Check Does

This check examines each Domain Controller for:
Driver signing policy registry check

## Risk

Malicious driver installation, kernel-level compromise, rootkit installation.

## Remediation

Enable driver signature enforcement via Group Policy or registry.

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
