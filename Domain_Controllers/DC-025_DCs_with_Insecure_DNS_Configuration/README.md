# DC-049: DCs with Insecure DNS Configuration

## Description

Identifies Domain Controllers with insecure DNS configurations including unrestricted zone transfers, missing DNSSEC, or insecure forwarders.

## Severity

**HIGH**

## Category

Domain Controllers

## What This Check Does

This check examines each Domain Controller for:
DNS server configuration analysis via WMI and dnscmd

## Risk

DNS poisoning, zone enumeration, man-in-the-middle attacks, information disclosure.

## Remediation

Restrict zone transfers, enable DNSSEC, configure secure forwarders, disable recursion where appropriate.

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
