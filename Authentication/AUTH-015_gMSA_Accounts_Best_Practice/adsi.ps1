# Check: gMSA Accounts (Best Practice)
# Category: Authentication
# Severity: medium
# ID: AUTH-015
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(objectClass=msDS-GroupManagedServiceAccount)'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'samAccountName', 'msDS-ManagedPasswordInterval', 'msDS-HostServiceAccount') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'gMSA Accounts (Best Practice)'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
