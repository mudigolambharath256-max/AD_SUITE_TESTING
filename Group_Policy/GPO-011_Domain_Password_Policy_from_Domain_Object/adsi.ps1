# Check: Domain Password Policy (from Domain Object)
# Category: Group Policy
# Severity: medium
# ID: GPO-011
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
    Label = 'Domain Password Policy (from Domain Object)'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
