# Check: Membership: Group Policy Creator Owners
# Category: Privileged Access
# Severity: medium
# ID: PRV-010
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=group)(cn=Group Policy Creator Owners))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'member') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Membership: Group Policy Creator Owners'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
