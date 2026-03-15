# Check: Accounts with Constrained Delegation
# Category: Users & Accounts
# Severity: medium
# ID: USR-031
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(msDS-AllowedToDelegateTo=*))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
(@('name', 'distinguishedName', 'samAccountName', 'msDS-AllowedToDelegateTo', 'userAccountControl', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Accounts with Constrained Delegation'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
UserAccountControl = if ($props['useraccountcontrol'].Count -gt 0) { $props['useraccountcontrol'][0]
MsDsAllowedToDelegateTo = if ($props['msds-allowedtodelegateto'].Count -gt 0) { $props['msds-allowedtodelegateto']
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } } else { 'N/A'
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } }
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } } else { 'N/A'
MsDsAllowedToDelegateTo = if ($props['msds-allowedtodelegateto'].Count -gt 0) { $props['msds-allowedtodelegateto']
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } } else { 'N/A'
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } }
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } }
MsDsAllowedToDelegateTo = if ($props['msds-allowedtodelegateto'].Count -gt 0) { $props['msds-allowedtodelegateto']
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } } else { 'N/A'
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } }
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' }
  }
}
