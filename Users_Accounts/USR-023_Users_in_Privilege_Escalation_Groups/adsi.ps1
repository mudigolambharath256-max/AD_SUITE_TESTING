# Check: Users in Privilege Escalation Groups
# Category: Users & Accounts
# Severity: medium
# ID: USR-023
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=person)(objectClass=user)(|(memberOf:1.2.840.113556.1.4.1941:=CN=Backup Operators,CN=Builtin,*)(memberOf:1.2.840.113556.1.4.1941:=CN=Account Operators,CN=Builtin,*)(memberOf:1.2.840.113556.1.4.1941:=CN=Server Operators,CN=Builtin,*)(memberOf:1.2.840.113556.1.4.1941:=CN=Print Operators,CN=Builtin,*)))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'samAccountName', 'memberOf', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Users in Privilege Escalation Groups'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' }
  }
}
