# Check: Default Password Policy
# Category: Authentication
# Severity: medium
# ID: AUTH-011
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(objectClass=domainDNS)'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'minPwdLength', 'pwdHistoryLength', 'lockoutThreshold', 'lockoutDuration', 'maxPwdAge', 'minPwdAge', 'pwdProperties') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Default Password Policy'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
