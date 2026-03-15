# Check: Service Accounts Missing msDS-SupportedEncryptionTypes
# Category: Service Accounts
# Severity: medium
# ID: SVC-006
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(!(msDS-SupportedEncryptionTypes=*)))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
(@('name', 'distinguishedName', 'samAccountName', 'servicePrincipalName', 'userAccountControl', 'msDS-SupportedEncryptionTypes', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Service Accounts Missing msDS-SupportedEncryptionTypes'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
UserAccountControl = if ($props['useraccountcontrol'].Count -gt 0) { $props['useraccountcontrol'][0]
MsDsSupportedEncryptionTypes = if ($props['msds-supportedencryptiontypes'].Count -gt 0) { $props['msds-supportedencryptiontypes'][0]
ServicePrincipalName = if ($props['serviceprincipalname'].Count -gt 0) { $props['serviceprincipalname']
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } } else { 'N/A'
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } }
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } } else { 'N/A'
ServicePrincipalName = if ($props['serviceprincipalname'].Count -gt 0) { $props['serviceprincipalname']
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } } else { 'N/A'
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } }
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } }
ServicePrincipalName = if ($props['serviceprincipalname'].Count -gt 0) { $props['serviceprincipalname']
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } } else { 'N/A'
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } }
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } } else { 'N/A'
MsDsSupportedEncryptionTypes = if ($props['msds-supportedencryptiontypes'].Count -gt 0) { $props['msds-supportedencryptiontypes'][0]
ServicePrincipalName = if ($props['serviceprincipalname'].Count -gt 0) { $props['serviceprincipalname']
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } } else { 'N/A'
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } }
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } } else { 'N/A'
ServicePrincipalName = if ($props['serviceprincipalname'].Count -gt 0) { $props['serviceprincipalname']
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } } else { 'N/A'
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } }
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } }
ServicePrincipalName = if ($props['serviceprincipalname'].Count -gt 0) { $props['serviceprincipalname']
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } } else { 'N/A'
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } }
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } }
MsDsSupportedEncryptionTypes = if ($props['msds-supportedencryptiontypes'].Count -gt 0) { $props['msds-supportedencryptiontypes'][0]
ServicePrincipalName = if ($props['serviceprincipalname'].Count -gt 0) { $props['serviceprincipalname']
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } } else { 'N/A'
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } }
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } } else { 'N/A'
ServicePrincipalName = if ($props['serviceprincipalname'].Count -gt 0) { $props['serviceprincipalname']
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } } else { 'N/A'
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } }
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } }
ServicePrincipalName = if ($props['serviceprincipalname'].Count -gt 0) { $props['serviceprincipalname']
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } } else { 'N/A'
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } }
SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' }
  }
}
