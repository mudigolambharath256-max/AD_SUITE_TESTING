# Check: Administrators Group Membership
# Category: Access_Control
# Severity: critical
# ID: ACC-024
# Requirements: None
# ============================================

# LDAP Filter: (&(objectCategory=group)(cn=Administrators))

[ADSISearcher] $searcher = New-Object System.DirectoryServices.DirectorySearcher
$searcher.Filter = "(&(objectCategory=group)(cn=Administrators))"
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.AddRange(@('name', 'distinguishedName', 'cn', 'member'))

$results = $searcher.FindAll()
$results | ForEach-Object {
    $obj = $_
    $props_dict = @{}
    foreach ($prop in $obj.Properties.PropertyNames) {
        $props_dict[$prop] = $obj.Properties[$prop][0]
    }
    [PSCustomObject]$props_dict
}

