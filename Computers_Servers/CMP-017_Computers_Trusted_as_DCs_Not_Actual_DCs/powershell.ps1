# Check: Computers Trusted as DCs (Not Actual DCs)
# Category: Computers & Servers
# Severity: critical
# ID: CMP-017
# Requirements: ActiveDirectory module (RSAT)
# ============================================

# LDAP search (PowerShell AD module)
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(userAccountControl:1.2.840.113556.1.4.803:=8192)(!(primaryGroupID=516)))'
$props = @('name', 'distinguishedName', 'samAccountName', 'userAccountControl', 'primaryGroupID')

Get-ADObject -LDAPFilter $ldapFilter -Properties $props -ErrorAction Stop |
  Select-Object name, distinguishedName, samAccountName, userAccountControl, primaryGroupID |
  Sort-Object name |
  ForEach-Object { $_ }
