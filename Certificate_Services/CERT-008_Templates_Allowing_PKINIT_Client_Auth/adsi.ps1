# Check: Templates Allowing PKINIT Client Auth
# Category: Certificate Services
# Severity: medium
# ID: CERT-008
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=pKICertificateTemplate)(pKIExtendedKeyUsage=1.3.6.1.5.2.3.4))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'displayName', 'pKIExtendedKeyUsage') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Templates Allowing PKINIT Client Auth'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
