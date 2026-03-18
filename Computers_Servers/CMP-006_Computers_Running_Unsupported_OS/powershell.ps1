# Check: Computers Running Unsupported OS
# Category: Computers & Servers
# Severity: critical
# ID: CMP-006
# Requirements: ActiveDirectory module (RSAT)
# ============================================

# LDAP search (PowerShell AD module)
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(|(operatingSystem=*XP*)(operatingSystem=*Vista*)(operatingSystem=*Windows 7*)(operatingSystem=*2003*)(operatingSystem=*2008*)(operatingSystem=*2012 *)))'
$props = @('name', 'distinguishedName', 'samAccountName', 'operatingSystem', 'operatingSystemVersion', 'lastLogonTimestamp')

Get-ADObject -LDAPFilter $ldapFilter -Properties $props -ErrorAction Stop |
  Select-Object name, distinguishedName, samAccountName, operatingSystem, operatingSystemVersion, lastLogonTimestamp |
  Sort-Object name |
  ForEach-Object { $_ }
