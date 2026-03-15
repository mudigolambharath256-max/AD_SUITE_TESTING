# Check: Protected Users Group Members
# Category: Privileged Access
# Severity: medium
# ID: PRV-021
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=group)(cn=Protected Users))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'member') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Protected Users Group Members'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
