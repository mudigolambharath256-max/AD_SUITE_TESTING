# Check: Templates with No Expiration Validation
# Category: Certificate Services
# Severity: medium
# ID: CERT-015
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=pKICertificateTemplate)(!(pKIExpirationPeriod=*)))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'displayName') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Templates with No Expiration Validation'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
