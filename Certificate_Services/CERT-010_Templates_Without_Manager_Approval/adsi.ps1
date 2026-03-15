# Check: Templates Without Manager Approval
# Category: Certificate Services
# Severity: medium
# ID: CERT-010
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=pKICertificateTemplate)(!(msPKI-Enrollment-Flag:1.2.840.113556.1.4.803:=2)))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'displayName', 'msPKI-Enrollment-Flag') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Templates Without Manager Approval'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
