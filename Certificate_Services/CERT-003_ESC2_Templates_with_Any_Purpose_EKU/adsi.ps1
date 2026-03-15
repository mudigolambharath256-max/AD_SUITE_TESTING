# Check: ESC2: Templates with Any Purpose EKU
# Category: Certificate Services
# Severity: medium
# ID: CERT-003
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=pKICertificateTemplate)(|(pKIExtendedKeyUsage=2.5.29.37.0)(!(pKIExtendedKeyUsage=*))))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'displayName', 'pKIExtendedKeyUsage') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'ESC2: Templates with Any Purpose EKU'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
