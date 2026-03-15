# Check: Authentication Policy Silos
# Category: Authentication
# Severity: medium
# ID: AUTH-028
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(objectClass=msDS-AuthNPolicySilo)'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'msDS-AuthNPolicySiloEnforced') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Authentication Policy Silos'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
