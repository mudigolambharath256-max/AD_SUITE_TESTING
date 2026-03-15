# Check: Membership: Remote Desktop Users
# Category: Privileged Access
# Severity: medium
# ID: PRV-012
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=group)(cn=Remote Desktop Users))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'member') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Membership: Remote Desktop Users'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
