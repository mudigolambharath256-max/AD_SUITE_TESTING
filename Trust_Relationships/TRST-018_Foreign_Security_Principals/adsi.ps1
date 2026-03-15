# Check: Foreign Security Principals
# Category: Trust Relationships
# Severity: medium
# ID: TRST-018
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(objectClass=foreignSecurityPrincipal)'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Foreign Security Principals'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
