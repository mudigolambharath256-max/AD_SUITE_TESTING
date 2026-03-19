# Check: Computers Missing Encryption Types
# Category: Computers & Servers
# Severity: medium
# ID: COMP-015
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(!(msDS-SupportedEncryptionTypes=*)))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
(@('name', 'distinguishedName', 'samAccountName', 'operatingSystem', 'userAccountControl', 'msDS-SupportedEncryptionTypes') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) })
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Computers Missing Encryption Types'
  }
}
