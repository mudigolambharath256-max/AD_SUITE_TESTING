# Check: Standalone Managed Service Accounts (sMSA)
# Category: Users & Accounts
# Severity: medium
# ID: USR-027
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(objectClass=msDS-ManagedServiceAccount)'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'samAccountName', 'msDS-ManagedPasswordInterval', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Standalone Managed Service Accounts (sMSA)'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
