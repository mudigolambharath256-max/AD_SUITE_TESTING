# Check: OUs Blocking Inheritance
# Category: Group Policy
# Severity: medium
# ID: GPO-014
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=organizationalUnit)(gPOptions=1))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'ou', 'gPOptions', 'gPLink') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'OUs Blocking Inheritance'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
