# Check: Hybrid Azure AD Joined Devices
# Category: Azure AD Integration
# Severity: medium
# ID: AAD-024
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=computer)(msDS-DeviceID=*))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'samAccountName', 'msDS-DeviceID', 'operatingSystem') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Hybrid Azure AD Joined Devices'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
