# Check: ESC3: Templates with Certificate Request Agent
# Category: Certificate Services
# Severity: medium
# ID: CERT-004
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=pKICertificateTemplate)(pKIExtendedKeyUsage=1.3.6.1.4.1.311.20.2.1))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'displayName', 'pKIExtendedKeyUsage') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'ESC3: Templates with Certificate Request Agent'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
