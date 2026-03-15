# Check: Cross-Forest Trusts Encryption Types
# Category: Trust Relationships
# Severity: medium
# ID: TRST-012
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(objectClass=trustedDomain)'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'flatName', 'msDS-SupportedEncryptionTypes', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Cross-Forest Trusts Encryption Types'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
