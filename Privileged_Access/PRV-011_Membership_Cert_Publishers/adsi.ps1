# Check: Membership: Cert Publishers
# Category: Privileged Access
# Severity: medium
# ID: PRV-011
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=group)(cn=Cert Publishers))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'member') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Membership: Cert Publishers'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
