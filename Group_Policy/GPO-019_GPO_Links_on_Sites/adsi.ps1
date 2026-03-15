# Check: GPO Links on Sites
# Category: Group Policy
# Severity: medium
# ID: GPO-019
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=site)(gPLink=*))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'gPLink') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'GPO Links on Sites'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
