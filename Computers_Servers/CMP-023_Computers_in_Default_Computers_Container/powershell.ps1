# Check: Computers in Default Computers Container
# Category: Computers & Servers
# Severity: medium
# ID: CMP-023
# Requirements: ActiveDirectory module (RSAT)
# ============================================

# LDAP search (PowerShell AD module)
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))'
$props = @('name', 'distinguishedName', 'samAccountName')

Get-ADObject -LDAPFilter $ldapFilter -Properties $props -ErrorAction Stop |
  Select-Object name, distinguishedName, samAccountName |
  Sort-Object name |
  ForEach-Object { $_ }
