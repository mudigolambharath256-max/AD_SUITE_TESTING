# DCONF-007 — NTLMv1 Protocol Allowed

## Purpose
Detects domain controllers that allow NTLMv1 authentication, which is vulnerable to pass-the-hash attacks and should be disabled in favor of NTLMv2-only authentication.

## Attack Scenario
Attackers can exploit NTLMv1's weak cryptography to perform pass-the-hash attacks, credential relay attacks, and offline password cracking. NTLMv1 uses weak DES encryption and is susceptible to rainbow table attacks.

## LDAP Details
| Field        | Value                          |
|--------------|-------------------------------|
| Filter       | `(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))` |
| Search Base  | `<DomainDN>`                   |
| Partition    | Default NC                     |
| Object Class | `computer`                     |
| Scope        | Subtree                        |

## Attributes Returned
- `name` — DC computer name
- `dNSHostName` — DC FQDN
- `distinguishedName` — DC object DN

## Registry Check
- **Path**: `HKLM\SYSTEM\CurrentControlSet\Control\Lsa`
- **Value**: `LmCompatibilityLevel`
- **Safe Setting**: 5 (Send NTLMv2 response only, refuse LM and NTLM)

## Execution
```powershell
# PowerShell (AD Module)
.\powershell.ps1

# ADSI (no module required)
.\adsi.ps1

# Combined (auto-detects best engine)
.\combined_multiengine.ps1
```

## Expected Output
Domain controllers with LmCompatibilityLevel < 5 are flagged based on severity:
- Level 0-2: CRITICAL (allows LM/NTLM)
- Level 3-4: HIGH (allows NTLM)

## Remediation
1. Set LmCompatibilityLevel to 5 on all domain controllers:
   ```
   reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v LmCompatibilityLevel /t REG_DWORD /d 5 /f
   ```
2. Configure via Group Policy: Computer Configuration → Windows Settings → Security Settings → Local Policies → Security Options → "Network security: LAN Manager authentication level"
3. Test application compatibility before enforcing
4. Restart affected services or reboot domain controllers

## References
- [LAN Manager Authentication Level](https://docs.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/network-security-lan-manager-authentication-level)
- MITRE ATT&CK: T1557.001 (LLMNR/NBT-NS Poisoning and SMB Relay)