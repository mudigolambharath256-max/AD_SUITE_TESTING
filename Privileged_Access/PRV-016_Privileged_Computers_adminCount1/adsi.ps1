# Check: Privileged Computers (adminCount=1)
# Category: Privileged Access
# Severity: medium
# ID: PRV-016
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=computer)(adminCount=1))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'samAccountName', 'adminCount', 'operatingSystem') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Privileged Computers (adminCount=1)'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
