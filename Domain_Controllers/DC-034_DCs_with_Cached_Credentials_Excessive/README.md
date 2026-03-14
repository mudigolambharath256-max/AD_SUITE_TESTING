# DC-058: DCs with Cached Credentials Excessive

## Description

Identifies Domain Controllers with excessive cached logon credentials configured.

## Severity

**MEDIUM**

## Category

Domain Controllers

## What This Check Does

This check examines each Domain Controller for:
CachedLogonsCount registry value check

## Risk

Offline credential attacks, increased credential exposure.

## Remediation

Set CachedLogonsCount to 0 or minimal value on Domain Controllers.

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
