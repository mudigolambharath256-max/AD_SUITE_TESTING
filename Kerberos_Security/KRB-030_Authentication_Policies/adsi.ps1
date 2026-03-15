# Check: Authentication Policies
# Category: Kerberos Security
# Severity: medium
# ID: KRB-030
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(objectClass=msDS-AuthNPolicy)'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'msDS-UserAllowedToAuthenticateTo') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Authentication Policies'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
