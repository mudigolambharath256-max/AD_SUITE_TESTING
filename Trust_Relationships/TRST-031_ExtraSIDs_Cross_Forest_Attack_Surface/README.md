# TRST-031 — ExtraSIDs Cross Forest Attack Surface

## Purpose
Detects forest trusts vulnerable to ExtraSIDs attacks where SID filtering is disabled, allowing attackers to inject privileged SIDs from trusted forests to escalate privileges.

## Attack Scenario
When SID filtering is disabled on forest trusts, attackers can create golden tickets with ExtraSIDs containing privileged SIDs from the target forest (e.g., Enterprise Admins S-1-5-21-<targetforest>-519). These tickets are accepted across the trust, granting administrative access to the target forest without legitimate credentials.

## LDAP Details
| Field        | Value                          |
|--------------|-------------------------------|
| Filter       | `(&(objectClass=trustedDomain)(trustType=2))` |
| Search Base  | `CN=System,<DomainDN>`         |
| Partition    | Default NC                     |
| Object Class | `trustedDomain`                |
| Scope        | Subtree                        |

## Attributes Returned
- `trustPartner` — Target forest name
- `trustDirection` — Trust direction (1=inbound, 2=outbound, 3=bidirectional)
- `trustType` — Trust type (2=forest trust)
- `trustAttributes` — Trust attribute flags
- `securityIdentifier` — Trust SID

## Trust Attribute Analysis
- **Bit 0x04 (TREAT_AS_EXTERNAL)**: When NOT set, SID filtering is disabled (CRITICAL)
- **Bit 0x08 (USES_RC4_ENCRYPTION)**: RC4 encryption used (downgrade risk)
- **Bit 0x20 (CROSS_ORGANIZATION)**: Selective authentication enabled (safer)

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
- Forest trusts with SID filtering disabled: CRITICAL severity
- Forest trusts with other risky attributes: HIGH severity
- Accounts with cross-forest SID History: HIGH severity

## Remediation
1. **Enable SID filtering on forest trusts**:
   ```
   netdom trust <source_domain> /domain:<target_domain> /quarantine:yes
   ```

2. **Enable selective authentication**:
   ```
   netdom trust <source_domain> /domain:<target_domain> /selectiveauth:yes
   ```

3. **Review and remove unnecessary SID History**:
   ```powershell
   # Review accounts with SID History
   Get-ADUser -Filter "SIDHistory -like '*'" -Properties SIDHistory
   
   # Remove SID History (use with caution)
   # Set-ADUser -Identity <user> -Remove @{SIDHistory=<sid_to_remove>}
   ```

4. **Monitor for ExtraSIDs attacks**:
   - Enable advanced audit policies for Kerberos authentication
   - Monitor Event ID 4769 for unusual SID patterns in service tickets
   - Implement SID filtering monitoring

## References
- [SID Filtering and Forest Trusts](https://docs.microsoft.com/en-us/windows-server/identity/ad-ds/manage/understand-security-identifiers)
- [Golden Ticket Attacks](https://attack.mitre.org/techniques/T1558/001/)
- MITRE ATT&CK: T1134.005 (Access Token Manipulation: SID-History Injection)