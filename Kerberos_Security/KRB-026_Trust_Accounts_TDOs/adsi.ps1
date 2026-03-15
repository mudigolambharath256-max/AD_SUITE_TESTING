# Check: Trust Accounts (TDOs)
# Category: Kerberos Security
# Severity: medium
# ID: KRB-026
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(objectClass=trustedDomain)'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'trustDirection', 'trustType', 'trustAttributes', 'msDS-SupportedEncryptionTypes') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Trust Accounts (TDOs)'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
