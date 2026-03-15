# Check: GPOs with Both Settings Disabled
# Category: Group Policy
# Severity: medium
# ID: GPO-003
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=groupPolicyContainer)(flags=3))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'displayName', 'flags', 'whenChanged') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'GPOs with Both Settings Disabled'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
