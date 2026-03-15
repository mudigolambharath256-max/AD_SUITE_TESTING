# Check: Trust Attributes Analysis
# Category: Trust Relationships
# Severity: medium
# ID: TRST-021
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(objectClass=trustedDomain)'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'flatName', 'trustAttributes', 'trustDirection', 'trustType', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Trust Attributes Analysis'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
