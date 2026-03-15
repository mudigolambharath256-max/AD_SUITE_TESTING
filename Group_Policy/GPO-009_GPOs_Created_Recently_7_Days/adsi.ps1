# Check: GPOs Created Recently (7 Days)
# Category: Group Policy
# Severity: medium
# ID: GPO-009
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(objectClass=groupPolicyContainer)'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'displayName', 'whenCreated', 'gPCFileSysPath') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'GPOs Created Recently (7 Days)'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
