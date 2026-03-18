# Check: Windows Workstations Inventory
# Category: Computers & Servers
# Severity: info
# ID: CMP-012
# Requirements: ActiveDirectory module (RSAT)
# ============================================

# LDAP search (PowerShell AD module)
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(operatingSystem=*Windows*)(!(operatingSystem=*Server*)))'
$props = @('name', 'distinguishedName', 'samAccountName', 'operatingSystem', 'operatingSystemVersion')

Get-ADObject -LDAPFilter $ldapFilter -Properties $props -ErrorAction Stop |
  Select-Object name, distinguishedName, samAccountName, operatingSystem, operatingSystemVersion |
  Sort-Object name |
  ForEach-Object { $_ }
