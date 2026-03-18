# Check: Computers with Constrained Delegation
# Category: Computers & Servers
# Severity: high
# ID: CMP-002
# Requirements: ActiveDirectory module (RSAT)
# ============================================

# LDAP search (PowerShell AD module)
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(msDS-AllowedToDelegateTo=*))'
$props = @('name', 'distinguishedName', 'samAccountName', 'msDS-AllowedToDelegateTo', 'operatingSystem')

Get-ADObject -LDAPFilter $ldapFilter -Properties $props -ErrorAction Stop |
  Select-Object name, distinguishedName, samAccountName, msDS-AllowedToDelegateTo, operatingSystem |
  Sort-Object name |
  ForEach-Object { $_ }
