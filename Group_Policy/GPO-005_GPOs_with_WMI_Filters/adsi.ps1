# Check: GPOs with WMI Filters
# Category: Group Policy
# Severity: medium
# ID: GPO-005
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=groupPolicyContainer)(gPCWQLFilter=*))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'displayName', 'gPCWQLFilter') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'GPOs with WMI Filters'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
