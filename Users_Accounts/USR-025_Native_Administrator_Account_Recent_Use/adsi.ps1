# Check: Native Administrator Account Recent Use
# Category: Users & Accounts
# Severity: medium
# ID: USR-025
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=person)(objectClass=user)(objectSid=*-500))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'samAccountName', 'lastLogonTimestamp', 'pwdLastSet', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Native Administrator Account Recent Use'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' }
  }
}
