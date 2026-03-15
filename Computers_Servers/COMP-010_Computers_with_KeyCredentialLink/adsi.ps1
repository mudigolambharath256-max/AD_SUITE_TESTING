# Check: Computers with KeyCredentialLink
# Category: Computers & Servers
# Severity: medium
# ID: COMP-010
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(msDS-KeyCredentialLink=*))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
(@('name', 'distinguishedName', 'samAccountName', 'msDS-KeyCredentialLink', 'userAccountControl') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Computers with KeyCredentialLink'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
UserAccountControl = if ($props['useraccountcontrol'].Count -gt 0) { $props['useraccountcontrol'][0]
MsDsKeyCredentialLink = if ($props['msds-keycredentiallink'].Count -gt 0) { $props['msds-keycredentiallink'] } else { 'N/A' } } else { 'N/A'
MsDsKeyCredentialLink = if ($props['msds-keycredentiallink'].Count -gt 0) { $props['msds-keycredentiallink'] } else { 'N/A' } }
MsDsKeyCredentialLink = if ($props['msds-keycredentiallink'].Count -gt 0) { $props['msds-keycredentiallink'] } else { 'N/A' }
  }
}
