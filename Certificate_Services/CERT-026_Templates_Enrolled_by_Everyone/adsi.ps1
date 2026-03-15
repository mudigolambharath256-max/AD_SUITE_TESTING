# Check: Templates Enrolled by Everyone
# Category: Certificate Services
# Severity: medium
# ID: CERT-026
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
    Label = 'Templates Enrolled by Everyone'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
