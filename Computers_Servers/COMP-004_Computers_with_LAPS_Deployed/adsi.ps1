# Check: Computers with LAPS Deployed
# Category: Computers & Servers
# Severity: medium
# ID: COMP-004
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(ms-Mcs-AdmPwd=*))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
(@('name', 'distinguishedName', 'samAccountName', 'ms-Mcs-AdmPwdExpirationTime', 'operatingSystem', 'userAccountControl') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) })
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Computers with LAPS Deployed'
  }
}
