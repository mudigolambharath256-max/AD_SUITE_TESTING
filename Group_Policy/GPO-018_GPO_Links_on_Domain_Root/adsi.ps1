# Check: GPO Links on Domain Root
# Category: Group Policy
# Severity: medium
# ID: GPO-018
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=domainDNS)(gPLink=*))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'gPLink') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'GPO Links on Domain Root'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
