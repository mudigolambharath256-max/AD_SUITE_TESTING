# Check: Directory Sync Status Container
# Category: Azure AD Integration
# Severity: medium
# ID: AAD-023
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(objectClass=msDS-DeviceRegistrationService)'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Directory Sync Status Container'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
