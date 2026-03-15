# Check: Templates Without Authorized Signatures Required
# Category: Certificate Services
# Severity: medium
# ID: CERT-011
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=pKICertificateTemplate)(|(msPKI-RA-Signature=0)(!(msPKI-RA-Signature=*))))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'displayName', 'msPKI-RA-Signature') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Templates Without Authorized Signatures Required'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
