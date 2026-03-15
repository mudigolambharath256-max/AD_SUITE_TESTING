# Check: Orphaned Foreign Security Principals
# Category: Trust Relationships
# Severity: medium
# ID: TRST-019
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=foreignSecurityPrincipal)(cn=S-1-5-21-*))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'objectSid', 'memberOf') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Orphaned Foreign Security Principals'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
