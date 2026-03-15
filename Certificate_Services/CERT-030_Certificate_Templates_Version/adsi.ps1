# Check: Certificate Templates Version
# Category: Certificate Services
# Severity: medium
# ID: CERT-030
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(objectClass=pKICertificateTemplate)'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'displayName', 'msPKI-Template-Schema-Version', 'msPKI-Template-Minor-Revision') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Certificate Templates Version'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
