# Check: Constrained Delegation Principals
# Category: Access_Control
# Severity: high
# ID: ACC-028
# Requirements: None
# ============================================

# LDAP Filter: (&(!(userAccountControl:1.2.840.113556.1.4.803:=2))(msDS-AllowedToDelegateTo=*))

[ADSISearcher] $searcher = New-Object System.DirectoryServices.DirectorySearcher
$searcher.Filter = "(&(!(userAccountControl:1.2.840.113556.1.4.803:=2))(msDS-AllowedToDelegateTo=*))"
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.AddRange(@('name', 'distinguishedName', 'samAccountName', 'objectClass', 'msDS-AllowedToDelegateTo'))

$results = $searcher.FindAll()
$results | ForEach-Object {
    $obj = $_
    $props_dict = @{}
    foreach ($prop in $obj.Properties.PropertyNames) {
        $props_dict[$prop] = $obj.Properties[$prop][0]
    }
    [PSCustomObject]$props_dict
}

