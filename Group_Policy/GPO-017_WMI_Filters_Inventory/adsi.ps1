# Check: WMI Filters Inventory
# Category: Group Policy
# Severity: medium
# ID: GPO-017
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(objectClass=msWMI-Som)'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'msWMI-Name', 'msWMI-Author', 'msWMI-Parm2') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'WMI Filters Inventory'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
