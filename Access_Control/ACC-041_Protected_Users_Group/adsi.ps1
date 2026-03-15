# Check: Protected Users Group
# Category: Access Control
# Severity: info
# ID: ACC-041
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=group)(cn=Protected Users))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'member', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }

$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Protected Users Group'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}