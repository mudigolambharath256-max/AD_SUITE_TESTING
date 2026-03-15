# Check: Trusts Created Recently (30 Days)
# Category: Trust Relationships
# Severity: medium
# ID: TRST-014
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(objectClass=trustedDomain)'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'flatName', 'whenCreated', 'whenChanged', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Trusts Created Recently (30 Days)'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
