# Check: Trust Security Identifiers
# Category: Trust Relationships
# Severity: medium
# ID: TRST-015
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(objectClass=trustedDomain)'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'flatName', 'securityIdentifier', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Trust Security Identifiers'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
