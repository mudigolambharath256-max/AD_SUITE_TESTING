# Check: ESC4: Templates with Weak Access Control
# Category: Certificate Services
# Severity: medium
# ID: CERT-005
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(objectClass=pKICertificateTemplate)'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'displayName', 'nTSecurityDescriptor') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'ESC4: Templates with Weak Access Control'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
