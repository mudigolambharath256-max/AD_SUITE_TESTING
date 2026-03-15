# Check: Trusts with RC4 Only
# Category: Trust Relationships
# Severity: medium
# ID: TRST-020
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=trustedDomain)(!(msDS-SupportedEncryptionTypes:1.2.840.113556.1.4.803:=24)))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'flatName', 'msDS-SupportedEncryptionTypes', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Trusts with RC4 Only'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
MsDsSupportedEncryptionTypes = if ($props['msds-supportedencryptiontypes'].Count -gt 0) { $props['msds-supportedencryptiontypes'][0] } else { 'N/A' }
  }
}
