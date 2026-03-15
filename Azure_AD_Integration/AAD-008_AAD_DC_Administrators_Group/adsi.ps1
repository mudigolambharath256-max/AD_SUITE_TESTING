# Check: AAD DC Administrators Group
# Category: Azure AD Integration
# Severity: medium
# ID: AAD-008
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=group)(cn=AAD DC Administrators))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'member') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'AAD DC Administrators Group'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
