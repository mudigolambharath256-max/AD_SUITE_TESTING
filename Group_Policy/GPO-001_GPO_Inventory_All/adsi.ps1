# Check: GPO Inventory (All)
# Category: Group Policy
# Severity: medium
# ID: GPO-001
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(objectClass=groupPolicyContainer)'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'displayName', 'gPCFileSysPath', 'versionNumber', 'flags', 'whenCreated') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'GPO Inventory (All)'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
