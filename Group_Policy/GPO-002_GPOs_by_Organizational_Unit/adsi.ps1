# Check: GPOs by Organizational Unit
# Category: Group Policy
# Severity: medium
# ID: GPO-002
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=organizationalUnit)(gPLink=*))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'ou', 'gPLink') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'GPOs by Organizational Unit'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
