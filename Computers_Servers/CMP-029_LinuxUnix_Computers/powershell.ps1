# Check: LinuxUnix Computers
# Category: Computers & Servers
# Severity: info
# ID: CMP-029
# Requirements: ActiveDirectory module (RSAT)
# ============================================

# LDAP search (PowerShell AD module)
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(!(operatingSystem=*Windows*)))'
$props = @('name', 'distinguishedName', 'samAccountName', 'operatingSystem', 'dNSHostName')

Get-ADObject -LDAPFilter $ldapFilter -Properties $props -ErrorAction Stop |
  Select-Object name, distinguishedName, samAccountName, operatingSystem, dNSHostName |
  Sort-Object name |
  ForEach-Object { $_ }
