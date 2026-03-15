# Check: OUs Without GPO Links
# Category: Group Policy
# Severity: medium
# ID: GPO-013
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=organizationalUnit)(!(gPLink=*)))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'ou') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'OUs Without GPO Links'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
