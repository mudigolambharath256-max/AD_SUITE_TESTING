# Check: Certificate Template Inventory
# Category: Certificate Services
# Severity: medium
# ID: CERT-001
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(objectClass=pKICertificateTemplate)'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'displayName', 'pKIExtendedKeyUsage', 'msPKI-Enrollment-Flag', 'msPKI-Certificate-Name-Flag', 'msPKI-RA-Signature') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Certificate Template Inventory'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
