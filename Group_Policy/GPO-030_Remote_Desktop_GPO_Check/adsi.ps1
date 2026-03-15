# Check: Remote Desktop GPO Check
# Category: Group Policy
# Severity: medium
# ID: GPO-030
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=groupPolicyContainer)(|(displayName=*rdp*)(displayName=*RDP*)(displayName=*remote*desktop*)))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'displayName', 'gPCFileSysPath') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Remote Desktop GPO Check'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
