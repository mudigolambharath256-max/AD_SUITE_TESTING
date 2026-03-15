# Check: ESC6: CA Allowing SAN in Requests
# Category: Certificate Services
# Severity: medium
# ID: CERT-020
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(objectClass=pKIEnrollmentService)'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'dNSHostName', 'flags') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'ESC6: CA Allowing SAN in Requests'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
