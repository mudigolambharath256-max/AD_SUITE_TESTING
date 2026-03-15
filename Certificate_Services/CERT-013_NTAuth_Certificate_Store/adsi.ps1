# Check: NTAuth Certificate Store
# Category: Certificate Services
# Severity: medium
# ID: CERT-013
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=certificationAuthority)(cn=NTAuthCertificates))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'cACertificate') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'NTAuth Certificate Store'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
