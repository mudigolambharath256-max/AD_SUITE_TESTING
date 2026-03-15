# Check: DCs with Constrained Delegation
# Category: Domain Controllers
# Severity: medium
# ID: DC-003
# Requirements: None
# ============================================

$root     = [ADSI]'LDAP://RootDSE'
    $domainNC = $root.defaultNamingContext.ToString()
            $searcher = New-Object System.DirectoryServices.DirectorySearcher
    $searcher.SearchRoot = [ADSI]"LDAP://$domainNC"
$searcher.Filter     = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192)(msDS-AllowedToDelegateTo=*))'
$searcher.PageSize   = 1000
$searcher.PropertiesToLoad.Clear()
(@('name', 'distinguishedName', 'samAccountName', 'msDS-AllowedToDelegateTo', 'userAccountControl') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
[PSCustomObject]@{
Label             = 'DCs with Constrained Delegation'
Name                      = $p['name'][0]
DistinguishedName         = $p['distinguishedname'][0]
SamAccountName            = $p['samaccountname'][0]
AllowedToDelegateTo       = $p['msds-allowedtodelegateto'][0]
UserAccountControl = if ($props['useraccountcontrol'].Count -gt 0) { $props['useraccountcontrol'][0]
MsDsAllowedToDelegateTo = if ($props['msds-allowedtodelegateto'].Count -gt 0) { $props['msds-allowedtodelegateto'] } else { 'N/A' } } else { 'N/A'
MsDsAllowedToDelegateTo = if ($props['msds-allowedtodelegateto'].Count -gt 0) { $props['msds-allowedtodelegateto'] } else { 'N/A' } }
MsDsAllowedToDelegateTo = if ($props['msds-allowedtodelegateto'].Count -gt 0) { $props['msds-allowedtodelegateto'] } else { 'N/A' }
}
}
