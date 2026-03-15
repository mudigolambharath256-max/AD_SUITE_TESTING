# Check: Trust Objects Without SecurityIdentifier
# Category: Trust Relationships
# Severity: medium
# ID: TRST-028
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=trustedDomain)(!(securityIdentifier=*)))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'flatName', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Trust Objects Without SecurityIdentifier'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
