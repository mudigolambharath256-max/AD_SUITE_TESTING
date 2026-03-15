# Check: Azure AD Provisioning Groups
# Category: Azure AD Integration
# Severity: medium
# ID: AAD-012
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=group)(|(cn=*Azure*)(cn=*AAD*)(cn=*O365*)(cn=*M365*)))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'member', 'description') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Azure AD Provisioning Groups'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
