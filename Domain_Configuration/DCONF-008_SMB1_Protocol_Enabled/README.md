# DCONF-008 — SMB1 Protocol Enabled

## Purpose
Detects domain controllers with SMB1 protocol enabled, which is a critical security vulnerability exploited by ransomware like WannaCry and should be completely disabled.

## Attack Scenario
SMB1 has numerous security vulnerabilities including buffer overflows, lack of encryption, and weak authentication. Attackers exploit SMB1 to spread laterally through networks, execute remote code, and deploy ransomware. The EternalBlue exploit specifically targets SMB1.

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

## Registry Checks
- **Server**: `HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters\SMB1` (should be 0)
- **Client**: `HKLM\SYSTEM\CurrentControlSet\Services\mrxsmb10\Start` (should be 4 = disabled)

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
Any domain controller with SMB1 enabled in any form is flagged as CRITICAL severity.

## Remediation
1. **Disable SMB1 Server**:
   ```
   reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v SMB1 /t REG_DWORD /d 0 /f
   ```

2. **Disable SMB1 Client**:
   ```
   reg add "HKLM\SYSTEM\CurrentControlSet\Services\mrxsmb10" /v Start /t REG_DWORD /d 4 /f
   ```

3. **Remove SMB1 Feature (Windows Server 2016+)**:
   ```powershell
   Remove-WindowsFeature FS-SMB1
   ```

4. **Remove SMB1 Optional Feature (Windows 10/Server 2019+)**:
   ```powershell
   Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol
   ```

5. **Restart affected services or reboot servers**

## References
- [Stop using SMB1](https://docs.microsoft.com/en-us/windows-server/storage/file-server/troubleshoot/stop-using-smb1)
- CVE-2017-0144 (EternalBlue)
- MITRE ATT&CK: T1021.002 (Remote Services: SMB/Windows Admin Shares)