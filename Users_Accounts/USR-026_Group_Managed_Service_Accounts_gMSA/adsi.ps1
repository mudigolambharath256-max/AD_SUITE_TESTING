# Check: Group Managed Service Accounts (gMSA)
# Category: Users & Accounts
# Severity: medium
# ID: USR-026
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(objectClass=msDS-GroupManagedServiceAccount)'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'samAccountName', 'msDS-ManagedPasswordInterval', 'msDS-HostServiceAccount', 'servicePrincipalName', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Group Managed Service Accounts (gMSA)'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
