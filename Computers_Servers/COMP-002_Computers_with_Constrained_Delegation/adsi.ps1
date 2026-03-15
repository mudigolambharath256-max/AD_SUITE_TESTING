# Check: Computers with Constrained Delegation
# Category: Computers & Servers
# Severity: medium
# ID: COMP-002
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(msDS-AllowedToDelegateTo=*))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
(@('name', 'distinguishedName', 'samAccountName', 'msDS-AllowedToDelegateTo', 'operatingSystem', 'userAccountControl') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Computers with Constrained Delegation'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
UserAccountControl = if ($props['useraccountcontrol'].Count -gt 0) { $props['useraccountcontrol'][0]
MsDsAllowedToDelegateTo = if ($props['msds-allowedtodelegateto'].Count -gt 0) { $props['msds-allowedtodelegateto'] } else { 'N/A' } } else { 'N/A'
MsDsAllowedToDelegateTo = if ($props['msds-allowedtodelegateto'].Count -gt 0) { $props['msds-allowedtodelegateto'] } else { 'N/A' } }
MsDsAllowedToDelegateTo = if ($props['msds-allowedtodelegateto'].Count -gt 0) { $props['msds-allowedtodelegateto'] } else { 'N/A' }
  }
}
