# Check: Incoming Forest Trust Builders
# Category: Privileged Access
# Severity: medium
# ID: PRV-025
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=group)(cn=Incoming Forest Trust Builders))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'member') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Incoming Forest Trust Builders'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
