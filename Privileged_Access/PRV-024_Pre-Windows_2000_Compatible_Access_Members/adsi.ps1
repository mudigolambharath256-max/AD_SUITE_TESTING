# Check: Pre-Windows 2000 Compatible Access Members
# Category: Privileged Access
# Severity: medium
# ID: PRV-024
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=group)(cn=Pre-Windows 2000 Compatible Access))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'member') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Pre-Windows 2000 Compatible Access Members'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
