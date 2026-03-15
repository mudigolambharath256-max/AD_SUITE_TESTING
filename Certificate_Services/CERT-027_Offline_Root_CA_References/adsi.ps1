# Check: Offline Root CA References
# Category: Certificate Services
# Severity: medium
# ID: CERT-027
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=certificationAuthority)(cn=*))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'cACertificate', 'certificateRevocationList') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Offline Root CA References'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
