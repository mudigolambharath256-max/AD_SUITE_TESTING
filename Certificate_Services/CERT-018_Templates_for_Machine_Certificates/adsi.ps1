# Check: Templates for Machine Certificates
# Category: Certificate Services
# Severity: medium
# ID: CERT-018
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=pKICertificateTemplate)(msPKI-Certificate-Name-Flag:1.2.840.113556.1.4.803:=536870912))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'displayName', 'msPKI-Certificate-Name-Flag') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Templates for Machine Certificates'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
