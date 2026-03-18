# Check: Computers with AltSecurityIdentities
# Category: Computers & Servers
# Severity: medium
# ID: CMP-025
# Requirements: ActiveDirectory module (RSAT)
# ============================================

# LDAP search (PowerShell AD module)
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(altSecurityIdentities=*))'
$props = @('name', 'distinguishedName', 'samAccountName', 'altSecurityIdentities')

Get-ADObject -LDAPFilter $ldapFilter -Properties $props -ErrorAction Stop |
  Select-Object name, distinguishedName, samAccountName, altSecurityIdentities |
  Sort-Object name |
  ForEach-Object { $_ }
