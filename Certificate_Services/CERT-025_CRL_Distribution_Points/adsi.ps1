# Check: CRL Distribution Points
# Category: Certificate Services
# Severity: medium
# ID: CERT-025
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=cRLDistributionPoint))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'CRL Distribution Points'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
