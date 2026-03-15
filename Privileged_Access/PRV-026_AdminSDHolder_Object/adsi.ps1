# Check: AdminSDHolder Object
# Category: Privileged Access
# Severity: medium
# ID: PRV-026
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=container)(cn=AdminSDHolder))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'nTSecurityDescriptor') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'AdminSDHolder Object'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
