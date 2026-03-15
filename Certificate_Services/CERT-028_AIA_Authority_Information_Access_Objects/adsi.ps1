# Check: AIA (Authority Information Access) Objects
# Category: Certificate Services
# Severity: medium
# ID: CERT-028
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=container)(cn=AIA))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'AIA (Authority Information Access) Objects'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
