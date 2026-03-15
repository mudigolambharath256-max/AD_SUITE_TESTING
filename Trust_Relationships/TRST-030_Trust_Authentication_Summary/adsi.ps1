# Check: Trust Authentication Summary
# Category: Trust Relationships
# Severity: medium
# ID: TRST-030
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(objectClass=trustedDomain)'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'flatName', 'trustPartner', 'trustDirection', 'trustType', 'trustAttributes', 'securityIdentifier', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Trust Authentication Summary'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
