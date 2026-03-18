# Check: Computers - Windows 10 Versions
# Category: Computers & Servers
# Severity: info
# ID: CMP-027
# Requirements: ActiveDirectory module (RSAT)
# ============================================

# LDAP search (PowerShell AD module)
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(operatingSystem=*Windows 10*))'
$props = @('name', 'distinguishedName', 'samAccountName', 'operatingSystem', 'operatingSystemVersion')

Get-ADObject -LDAPFilter $ldapFilter -Properties $props -ErrorAction Stop |
  Select-Object name, distinguishedName, samAccountName, operatingSystem, operatingSystemVersion |
  Sort-Object name |
  ForEach-Object { $_ }
