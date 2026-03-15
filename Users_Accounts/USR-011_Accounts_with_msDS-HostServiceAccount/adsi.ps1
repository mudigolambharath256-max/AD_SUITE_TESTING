# Check: Accounts with msDS-HostServiceAccount
# Category: Users & Accounts
# Severity: medium
# ID: USR-011
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=msDS-GroupManagedServiceAccount)(msDS-HostServiceAccount=*))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'samAccountName', 'msDS-HostServiceAccount', 'msDS-ManagedPasswordInterval', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Accounts with msDS-HostServiceAccount'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
