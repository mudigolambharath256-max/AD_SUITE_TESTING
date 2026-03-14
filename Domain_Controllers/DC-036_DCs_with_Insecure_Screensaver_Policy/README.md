# DC-060: DCs with Insecure Screensaver Policy

## Description

Identifies Domain Controllers without proper screensaver timeout and password protection.

## Severity

**MEDIUM**

## Category

Domain Controllers

## What This Check Does

This check examines each Domain Controller for:
Screensaver registry settings check

## Risk

Physical access to unlocked console, unauthorized local access.

## Remediation

Configure screensaver timeout (≤15 minutes) and password protection via GPO.

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
