# Check: Templates Allowing Renewal with Different Key
# Category: Certificate Services
# Severity: medium
# ID: CERT-019
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=pKICertificateTemplate)(msPKI-Enrollment-Flag:1.2.840.113556.1.4.803:=32))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'displayName', 'msPKI-Enrollment-Flag') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Templates Allowing Renewal with Different Key'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
