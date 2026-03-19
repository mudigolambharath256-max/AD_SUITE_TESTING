# Check: Computers with adminCount1
# Category: Computers & Servers
# Severity: medium
# ID: COMP-008
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(adminCount=1))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
(@('name', 'distinguishedName', 'samAccountName', 'adminCount', 'operatingSystem', 'userAccountControl') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) })
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Computers with adminCount1'
  }
}
