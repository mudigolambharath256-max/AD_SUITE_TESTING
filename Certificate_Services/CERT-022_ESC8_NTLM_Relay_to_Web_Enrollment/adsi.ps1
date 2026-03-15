# Check: ESC8: NTLM Relay to Web Enrollment
# Category: Certificate Services
# Severity: medium
# ID: CERT-022
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(objectClass=pKIEnrollmentService)'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'dNSHostName') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'ESC8: NTLM Relay to Web Enrollment'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
