# Check: GPO Containing Password (Naming)
# Category: Group Policy
# Severity: medium
# ID: GPO-006
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=groupPolicyContainer)(|(displayName=*password*)(displayName=*Password*)(displayName=*PASSWORD*)))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'displayName', 'gPCFileSysPath') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'GPO Containing Password (Naming)'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
