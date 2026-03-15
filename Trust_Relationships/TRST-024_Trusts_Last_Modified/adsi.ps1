# Check: Trusts Last Modified
# Category: Trust Relationships
# Severity: medium
# ID: TRST-024
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(objectClass=trustedDomain)'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'flatName', 'whenChanged', 'modifyTimeStamp', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Trusts Last Modified'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
