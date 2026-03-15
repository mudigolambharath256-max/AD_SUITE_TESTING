# Check: Sync Server Computer Accounts
# Category: Azure AD Integration
# Severity: medium
# ID: AAD-020
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=computer)(|(cn=*AADConnect*)(cn=*AADC*)(description=*Azure AD Connect*)))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'samAccountName', 'dNSHostName', 'operatingSystem', 'description') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Sync Server Computer Accounts'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
