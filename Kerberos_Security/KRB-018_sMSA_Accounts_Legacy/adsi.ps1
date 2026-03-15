# Check: sMSA Accounts (Legacy)
# Category: Kerberos Security
# Severity: medium
# ID: KRB-018
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(objectClass=msDS-ManagedServiceAccount)'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'samAccountName', 'msDS-ManagedPasswordInterval') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'sMSA Accounts (Legacy)'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
