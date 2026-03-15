# Check: Enterprise Certificate Authorities
# Category: Certificate Services
# Severity: medium
# ID: CERT-012
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(objectClass=pKIEnrollmentService)'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'dNSHostName', 'cACertificate', 'certificateTemplates') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Enterprise Certificate Authorities'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
