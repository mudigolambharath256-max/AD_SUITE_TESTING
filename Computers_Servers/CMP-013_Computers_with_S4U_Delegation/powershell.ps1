# Check: Computers with S4U Delegation
# Category: Computers & Servers
# Severity: high
# ID: CMP-013
# Requirements: ActiveDirectory module (RSAT)
# ============================================

# LDAP search (PowerShell AD module)
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(userAccountControl:1.2.840.113556.1.4.803:=16777216))'
$props = @('name', 'distinguishedName', 'samAccountName', 'userAccountControl', 'msDS-AllowedToDelegateTo')

Get-ADObject -LDAPFilter $ldapFilter -Properties $props -ErrorAction Stop |
  Select-Object name, distinguishedName, samAccountName, userAccountControl, msDS-AllowedToDelegateTo |
  Sort-Object name |
  ForEach-Object { $_ }
