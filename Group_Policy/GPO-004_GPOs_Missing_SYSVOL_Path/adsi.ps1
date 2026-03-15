# Check: GPOs Missing SYSVOL Path
# Category: Group Policy
# Severity: medium
# ID: GPO-004
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=groupPolicyContainer)(!(gPCFileSysPath=*)))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'displayName') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'GPOs Missing SYSVOL Path'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
