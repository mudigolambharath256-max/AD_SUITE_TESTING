# Check: ESC7: CA with Manage Certificates Permission
# Category: Certificate Services
# Severity: medium
# ID: CERT-021
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(objectClass=pKIEnrollmentService)'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'dNSHostName', 'nTSecurityDescriptor') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'ESC7: CA with Manage Certificates Permission'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
