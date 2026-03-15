# Check: Starter GPOs
# Category: Group Policy
# Severity: medium
# ID: GPO-016
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(objectClass=msGPOsForConfiguration)'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Starter GPOs'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
