# Check: Fine-Grained Password Policies
# Category: Authentication
# Severity: medium
# ID: AUTH-012
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(objectClass=msDS-PasswordSettings)'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'msDS-MinimumPasswordLength', 'msDS-PasswordComplexityEnabled', 'msDS-LockoutThreshold', 'msDS-PasswordSettingsPrecedence') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Fine-Grained Password Policies'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
