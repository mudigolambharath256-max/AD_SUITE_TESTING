# Check: Cross-Domain Group Memberships
# Category: Trust Relationships
# Severity: medium
# ID: TRST-023
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=group)(member=*CN=ForeignSecurityPrincipals*))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'member', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Cross-Domain Group Memberships'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
