# Check: Computers with RBCD Configured
# Category: Computers & Servers
# Severity: high
# ID: CMP-003
# Requirements: ActiveDirectory module (RSAT)
# ============================================

# LDAP search (PowerShell AD module)
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(msDS-AllowedToActOnBehalfOfOtherIdentity=*))'
$props = @('name', 'distinguishedName', 'samAccountName', 'msDS-AllowedToActOnBehalfOfOtherIdentity')

Get-ADObject -LDAPFilter $ldapFilter -Properties $props -ErrorAction Stop |
  Select-Object name, distinguishedName, samAccountName, msDS-AllowedToActOnBehalfOfOtherIdentity |
  Sort-Object name |
  ForEach-Object { $_ }
