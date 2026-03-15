# Check: Computers Running Unsupported OS
# Category: Computers & Servers
# Severity: medium
# ID: COMP-006
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(|(operatingSystem=*XP*)(operatingSystem=*Vista*)(operatingSystem=*Windows 7*)(operatingSystem=*2003*)(operatingSystem=*2008*)(operatingSystem=*2012 *)))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
(@('name', 'distinguishedName', 'samAccountName', 'operatingSystem', 'operatingSystemVersion', 'lastLogonTimestamp', 'userAccountControl') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Computers Running Unsupported OS'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
UserAccountControl = if ($props['useraccountcontrol'].Count -gt 0) { $props['useraccountcontrol'][0] } else { 'N/A' }
  }
}
