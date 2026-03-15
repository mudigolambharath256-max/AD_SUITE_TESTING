# Check: Exchange Windows Permissions Group
# Category: Privileged Access
# Severity: medium
# ID: PRV-027
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=group)(cn=Exchange Windows Permissions))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'member') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Exchange Windows Permissions Group'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
