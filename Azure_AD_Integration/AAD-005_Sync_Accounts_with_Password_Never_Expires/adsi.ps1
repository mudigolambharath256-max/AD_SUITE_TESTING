# Check: Sync Accounts with Password Never Expires
# Category: Azure AD Integration
# Severity: medium
# ID: AAD-005
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(|(samAccountName=MSOL_*)(samAccountName=AAD_*))(userAccountControl:1.2.840.113556.1.4.803:=65536))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'samAccountName', 'userAccountControl', 'pwdLastSet') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Sync Accounts with Password Never Expires'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0]
UserAccountControl = if ($props['useraccountcontrol'].Count -gt 0) { $props['useraccountcontrol'][0] } else { 'N/A' } } else { 'N/A'
UserAccountControl = if ($props['useraccountcontrol'].Count -gt 0) { $props['useraccountcontrol'][0] } else { 'N/A' } }
UserAccountControl = if ($props['useraccountcontrol'].Count -gt 0) { $props['useraccountcontrol'][0] } else { 'N/A' }
  }
}
