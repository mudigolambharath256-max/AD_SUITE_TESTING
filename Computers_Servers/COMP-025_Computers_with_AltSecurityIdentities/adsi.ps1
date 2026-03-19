# Check: Computers with AltSecurityIdentities
# Category: Computers & Servers
# Severity: medium
# ID: COMP-025
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(altSecurityIdentities=*))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
(@('name', 'distinguishedName', 'samAccountName', 'altSecurityIdentities', 'userAccountControl') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) })
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Computers with AltSecurityIdentities'
  }
}
