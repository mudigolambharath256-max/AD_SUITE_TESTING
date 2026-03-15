# Check: Trusted Root CAs in AD
# Category: Certificate Services
# Severity: medium
# ID: CERT-014
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=certificationAuthority)(cn=*))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'cACertificate') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Trusted Root CAs in AD'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
