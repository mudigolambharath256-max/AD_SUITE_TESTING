# Check: Templates Allowing Code Signing
# Category: Certificate Services
# Severity: medium
# ID: CERT-009
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=pKICertificateTemplate)(pKIExtendedKeyUsage=1.3.6.1.5.5.7.3.3))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'displayName', 'pKIExtendedKeyUsage') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Templates Allowing Code Signing'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
