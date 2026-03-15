# Check: BitLocker GPO Check
# Category: Group Policy
# Severity: medium
# ID: GPO-022
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=groupPolicyContainer)(|(displayName=*bitlocker*)(displayName=*BitLocker*)(displayName=*encryption*)))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'displayName', 'gPCFileSysPath') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'BitLocker GPO Check'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
