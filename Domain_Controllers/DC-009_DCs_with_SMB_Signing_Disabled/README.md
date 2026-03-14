# DCs with SMB Signing Disabled

## Description
This check identifies Domain Controllers that do not have SMB signing required, making them vulnerable to SMB relay attacks. SMB signing provides authentication and integrity protection for SMB communications, preventing man-in-the-middle attacks and credential relay attacks.

When SMB signing is not required (requireSecuritySignature != 1), attackers can perform SMB relay attacks to authenticate to other systems using captured credentials, potentially leading to lateral movement and privilege escalation.

## Severity
CRITICAL

## Category
Domain Controllers

## Technical Details

### Registry Key Checked
- **Path**: `HKLM\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters`
- **Key**: `requireSecuritySignature`
- **Expected Value**: `1` (DWORD)
- **Vulnerable Values**: `0` (disabled) or missing key

### LDAP Filter Used
```
(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))
```

This filter identifies Domain Controllers by checking:
- `objectCategory=computer`: Computer objects only
- `userAccountControl:1.2.840.113556.1.4.803:=8192`: UAC bit 8192 (SERVER_TRUST_ACCOUNT)

## Remediation

### Immediate Actions
1. **Enable SMB Signing on all Domain Controllers**:
   ```powershell
   # Set registry value on each DC
   Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters" -Name "requireSecuritySignature" -Value 1 -Type DWord
   
   # Restart the Server service (requires maintenance window)
   Restart-Service -Name "LanmanServer" -Force
   ```

2. **Via Group Policy** (Recommended):
   - Navigate to: `Computer Configuration > Policies > Windows Settings > Security Settings > Local Policies > Security Options`
   - Set: `Microsoft network server: Digitally sign communications (always)` to **Enabled**
   - Apply to Domain Controllers OU

### Verification
```powershell
# Verify the setting on each DC
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters" -Name "requireSecuritySignature"

# Check via Group Policy
gpresult /h gpresult.html
# Look for "Microsoft network server: Digitally sign communications (always)"
```

### Additional Hardening
1. **Enable SMB Client Signing**: Set `requireSecuritySignature` to 1 in `LanManWorkstation\Parameters`
2. **Disable SMBv1**: Ensure SMBv1 is disabled on all Domain Controllers
3. **Network Segmentation**: Isolate Domain Controllers in dedicated network segments
4. **Monitor SMB Traffic**: Implement monitoring for unsigned SMB connections

## Impact of Vulnerability

### Attack Scenarios
1. **SMB Relay Attacks**: Attackers can relay captured NTLM authentication to other systems
2. **Credential Harvesting**: Intercept and reuse authentication tokens
3. **Lateral Movement**: Use relayed credentials to access additional systems
4. **Privilege Escalation**: Relay DC machine account credentials for domain compromise

### Business Impact
- **Confidentiality**: Unauthorized access to sensitive domain data
- **Integrity**: Potential modification of domain objects and policies
- **Availability**: Risk of domain-wide service disruption
- **Compliance**: Violation of security frameworks (NIST, CIS, STIG)

## References
- [Microsoft SMB Signing Documentation](https://learn.microsoft.com/en-us/windows-server/storage/file-server/smb-security)
- [NIST SP 800-53 SC-8: Transmission Confidentiality and Integrity](https://nvd.nist.gov/800-53/Rev4/control/SC-8)
- [CIS Controls v8: 3.10 Encrypt Sensitive Data in Transit](https://www.cisecurity.org/controls/v8)
- [Windows Server Security Baseline](https://learn.microsoft.com/en-us/windows/security/threat-protection/windows-security-baselines)

## MITRE ATT&CK
- **Technique**: T1557.001 (Adversary-in-the-Middle: LLMNR/NBT-NS Poisoning and SMB Relay)
- **Tactic**: Credential Access, Collection
- **Sub-technique**: SMB Relay attacks to capture and reuse authentication tokens

## Detection Notes
- **False Positives**: Minimal - SMB signing should always be required on Domain Controllers
- **False Negatives**: May occur if remote registry access is blocked (reported as UNKNOWN)
- **Limitations**: Requires administrative privileges for remote registry access
- **Alternative Detection**: Monitor Event ID 2887 in Directory Service logs for unsigned LDAP binds

## File Implementations
- **adsi.ps1**: Native ADSI implementation with remote registry access
- **powershell.ps1**: PowerShell AD module with Invoke-Command for registry checks
- **cmd.bat**: Command-line implementation using dsquery and reg query
- **csharp.cs**: C# implementation using DirectoryServices and Registry classes
- **combined_multiengine.ps1**: Multi-engine approach with deduplication and comprehensive reporting