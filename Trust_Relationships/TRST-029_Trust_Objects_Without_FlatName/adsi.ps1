# Check: Trust Objects Without FlatName
# Category: Trust Relationships
# Severity: medium
# ID: TRST-029
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=trustedDomain)(!(flatName=*)))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Trust Objects Without FlatName'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
