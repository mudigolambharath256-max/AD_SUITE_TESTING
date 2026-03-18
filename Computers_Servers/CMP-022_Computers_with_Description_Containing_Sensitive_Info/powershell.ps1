# Check: Computers with Description Containing Sensitive Info
# Category: Computers & Servers
# Severity: low
# ID: CMP-022
# Requirements: ActiveDirectory module (RSAT)
# ============================================

# LDAP search (PowerShell AD module)
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(description=*))'
$props = @('name', 'distinguishedName', 'samAccountName', 'description')

Get-ADObject -LDAPFilter $ldapFilter -Properties $props -ErrorAction Stop |
  Select-Object name, distinguishedName, samAccountName, description |
  Sort-Object name |
  ForEach-Object { $_ }
