# Check: Templates with Exportable Private Key
# Category: Certificate Services
# Severity: medium
# ID: CERT-017
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=pKICertificateTemplate)(msPKI-Private-Key-Flag:1.2.840.113556.1.4.803:=16))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'displayName', 'msPKI-Private-Key-Flag') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Templates with Exportable Private Key'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
