# Check: Accounts with AES256 Only
# Category: Kerberos Security
# Severity: medium
# ID: KRB-023
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(!(userAccountControl:1.2.840.113556.1.4.803:=2))(msDS-SupportedEncryptionTypes=24))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
(@('name', 'distinguishedName', 'samAccountName', 'msDS-SupportedEncryptionTypes', 'userAccountControl') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Accounts with AES256 Only'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
UserAccountControl = if ($props['useraccountcontrol'].Count -gt 0) { $props['useraccountcontrol'][0]
MsDsSupportedEncryptionTypes = if ($props['msds-supportedencryptiontypes'].Count -gt 0) { $props['msds-supportedencryptiontypes'][0] } else { 'N/A' } } else { 'N/A'
MsDsSupportedEncryptionTypes = if ($props['msds-supportedencryptiontypes'].Count -gt 0) { $props['msds-supportedencryptiontypes'][0] } else { 'N/A' } }
MsDsSupportedEncryptionTypes = if ($props['msds-supportedencryptiontypes'].Count -gt 0) { $props['msds-supportedencryptiontypes'][0] } else { 'N/A' }
  }
}
