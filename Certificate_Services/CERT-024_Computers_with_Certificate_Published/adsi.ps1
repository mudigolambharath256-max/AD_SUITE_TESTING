# Check: Computers with Certificate Published
# Category: Certificate Services
# Severity: medium
# ID: CERT-024
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=computer)(userCertificate=*))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'samAccountName', 'userCertificate', 'operatingSystem') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Computers with Certificate Published'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
