# Check: SPN Duplicates Check (Computers)
# Category: Kerberos Security
# Severity: medium
# ID: KRB-028
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(servicePrincipalName=*))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
(@('name', 'distinguishedName', 'samAccountName', 'servicePrincipalName', 'userAccountControl') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'SPN Duplicates Check (Computers)'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
UserAccountControl = if ($props['useraccountcontrol'].Count -gt 0) { $props['useraccountcontrol'][0]
ServicePrincipalName = if ($props['serviceprincipalname'].Count -gt 0) { $props['serviceprincipalname'] } else { 'N/A' } } else { 'N/A'
ServicePrincipalName = if ($props['serviceprincipalname'].Count -gt 0) { $props['serviceprincipalname'] } else { 'N/A' } }
ServicePrincipalName = if ($props['serviceprincipalname'].Count -gt 0) { $props['serviceprincipalname'] } else { 'N/A' }
  }
}
