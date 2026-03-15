# Check: GPOs with Enforced Links
# Category: Group Policy
# Severity: medium
# ID: GPO-015
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=organizationalUnit)(gPLink=*2*))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'ou', 'gPLink') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'GPOs with Enforced Links'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
