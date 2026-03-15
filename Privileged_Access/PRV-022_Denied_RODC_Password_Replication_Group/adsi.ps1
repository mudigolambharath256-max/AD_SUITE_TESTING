# Check: Denied RODC Password Replication Group
# Category: Privileged Access
# Severity: medium
# ID: PRV-022
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=group)(cn=Denied RODC Password Replication Group))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'member') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Denied RODC Password Replication Group'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
