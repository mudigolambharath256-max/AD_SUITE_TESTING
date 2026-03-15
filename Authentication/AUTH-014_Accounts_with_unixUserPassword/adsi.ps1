# Check: Accounts with unixUserPassword
# Category: Authentication
# Severity: medium
# ID: AUTH-014
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=person)(objectClass=user)(unixUserPassword=*))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'samAccountName', 'unixUserPassword') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Accounts with unixUserPassword'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' }
  }
}
