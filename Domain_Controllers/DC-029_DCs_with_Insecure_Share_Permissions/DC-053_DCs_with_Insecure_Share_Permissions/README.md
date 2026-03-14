# DC-053: DCs with Insecure Share Permissions

## Description

Identifies Domain Controllers with insecure permissions on SYSVOL, NETLOGON, or other shares.

## Severity

**HIGH**

## Category

Domain Controllers

## What This Check Does

This check examines each Domain Controller for:
Share permission analysis for SYSVOL, NETLOGON, and other shares

## Risk

Unauthorized file access, GPO modification, malware distribution via SYSVOL.

## Remediation

Review and restrict share permissions, ensure SYSVOL/NETLOGON have proper ACLs.

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
