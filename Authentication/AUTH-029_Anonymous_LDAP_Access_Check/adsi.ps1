# Check: Anonymous LDAP Access Check
# Category: Authentication
# Severity: medium
# ID: AUTH-029
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=domainDNS)(dSHeuristics=0000002*))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'dSHeuristics') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Anonymous LDAP Access Check'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
