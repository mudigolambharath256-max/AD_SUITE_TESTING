# Check: Audit Policy GPO Check
# Category: Group Policy
# Severity: medium
# ID: GPO-024
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=groupPolicyContainer)(|(displayName=*audit*)(displayName=*Audit*)(displayName=*logging*)))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'displayName', 'gPCFileSysPath') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Audit Policy GPO Check'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
