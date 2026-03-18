# Check: Computers with adminCount1
# Category: Computers & Servers
# Severity: high
# ID: CMP-008
# Requirements: ActiveDirectory module (RSAT)
# ============================================

# LDAP search (PowerShell AD module)
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(adminCount=1))'
$props = @('name', 'distinguishedName', 'samAccountName', 'adminCount', 'operatingSystem')

Get-ADObject -LDAPFilter $ldapFilter -Properties $props -ErrorAction Stop |
  Select-Object name, distinguishedName, samAccountName, adminCount, operatingSystem |
  Sort-Object name |
  ForEach-Object { $_ }
