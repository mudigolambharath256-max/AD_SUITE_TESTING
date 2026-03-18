# Check: Computers with SIDHistory
# Category: Computers & Servers
# Severity: high
# ID: CMP-009
# Requirements: ActiveDirectory module (RSAT)
# ============================================

# LDAP search (PowerShell AD module)
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(sIDHistory=*))'
$props = @('name', 'distinguishedName', 'samAccountName', 'sIDHistory')

Get-ADObject -LDAPFilter $ldapFilter -Properties $props -ErrorAction Stop |
  Select-Object name, distinguishedName, samAccountName, sIDHistory |
  Sort-Object name |
  ForEach-Object { $_ }
