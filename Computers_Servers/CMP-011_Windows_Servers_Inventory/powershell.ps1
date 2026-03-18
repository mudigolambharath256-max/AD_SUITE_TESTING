# Check: Windows Servers Inventory
# Category: Computers & Servers
# Severity: info
# ID: CMP-011
# Requirements: ActiveDirectory module (RSAT)
# ============================================

# LDAP search (PowerShell AD module)
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(operatingSystem=*Server*))'
$props = @('name', 'distinguishedName', 'samAccountName', 'operatingSystem', 'operatingSystemVersion', 'lastLogonTimestamp')

Get-ADObject -LDAPFilter $ldapFilter -Properties $props -ErrorAction Stop |
  Select-Object name, distinguishedName, samAccountName, operatingSystem, operatingSystemVersion, lastLogonTimestamp |
  Sort-Object name |
  ForEach-Object { $_ }
