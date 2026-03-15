# Check: Templates Allowing Key Archival
# Category: Certificate Services
# Severity: medium
# ID: CERT-016
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=pKICertificateTemplate)(msPKI-Enrollment-Flag:1.2.840.113556.1.4.803:=8))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'displayName', 'msPKI-Enrollment-Flag') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Templates Allowing Key Archival'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
