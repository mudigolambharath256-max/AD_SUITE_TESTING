# Check: Computers with Managed Password (gMSA Hosts)
# Category: Computers & Servers
# Severity: medium
# ID: COMP-030
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=msDS-GroupManagedServiceAccount)(msDS-HostServiceAccount=*))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'samAccountName', 'msDS-HostServiceAccount') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Computers with Managed Password (gMSA Hosts)'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
