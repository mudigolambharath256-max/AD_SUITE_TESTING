# Check: GPOs Modified Recently
# Category: Group Policy
# Severity: medium
# ID: GPO-010
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(objectClass=groupPolicyContainer)'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'displayName', 'whenChanged', 'versionNumber') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'GPOs Modified Recently'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
