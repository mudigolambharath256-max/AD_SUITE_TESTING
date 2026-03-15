# Check: Computers with userPassword Attribute
# Category: Computers & Servers
# Severity: medium
# ID: COMP-021
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=computer)(userPassword=*))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'samAccountName', 'userPassword') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Computers with userPassword Attribute'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
