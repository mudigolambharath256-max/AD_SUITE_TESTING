# Check: Computers with userPassword Attribute
# Category: Computers & Servers
# Severity: high
# ID: CMP-021
# Requirements: ActiveDirectory module (RSAT)
# ============================================

# LDAP search (PowerShell AD module)
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectCategory=computer)(userPassword=*))'
$props = @('name', 'distinguishedName', 'samAccountName', 'userPassword')

Get-ADObject -LDAPFilter $ldapFilter -Properties $props -ErrorAction Stop |
  Select-Object name, distinguishedName, samAccountName, userPassword |
  Sort-Object name |
  ForEach-Object { $_ }
