# Check: Default Domain Policy
# Category: Group Policy
# Severity: medium
# ID: GPO-007
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=groupPolicyContainer)(cn={31B2F340-016D-11D2-945F-00C04FB984F9}))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'displayName', 'versionNumber', 'gPCFileSysPath') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Default Domain Policy'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
