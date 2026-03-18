# Check: Computers with Reversible Encryption
# Category: Computers & Servers
# Severity: critical
# ID: CMP-016
# Requirements: ActiveDirectory module (RSAT)
# ============================================

# LDAP search (PowerShell AD module)
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(userAccountControl:1.2.840.113556.1.4.803:=128))'
$props = @('name', 'distinguishedName', 'samAccountName', 'userAccountControl')

Get-ADObject -LDAPFilter $ldapFilter -Properties $props -ErrorAction Stop |
  Select-Object name, distinguishedName, samAccountName, userAccountControl |
  Sort-Object name |
  ForEach-Object { $_ }
