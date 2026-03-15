# Check: Computers Trusted as DCs (Not Actual DCs)
# Category: Computers & Servers
# Severity: medium
# ID: COMP-017
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(userAccountControl:1.2.840.113556.1.4.803:=8192)(!(primaryGroupID=516)))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'samAccountName', 'userAccountControl', 'primaryGroupID') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Computers Trusted as DCs (Not Actual DCs)'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
UserAccountControl = if ($props['useraccountcontrol'].Count -gt 0) { $props['useraccountcontrol'][0]
PrimaryGroupID = if ($props['primarygroupid'].Count -gt 0) { $props['primarygroupid'][0] } else { 'N/A' } } else { 'N/A'
PrimaryGroupID = if ($props['primarygroupid'].Count -gt 0) { $props['primarygroupid'][0] } else { 'N/A' } }
PrimaryGroupID = if ($props['primarygroupid'].Count -gt 0) { $props['primarygroupid'][0] } else { 'N/A' }
  }
}
