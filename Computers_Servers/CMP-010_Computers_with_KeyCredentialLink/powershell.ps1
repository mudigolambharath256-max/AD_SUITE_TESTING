# Check: Computers with KeyCredentialLink
# Category: Computers & Servers
# Severity: medium
# ID: CMP-010
# Requirements: ActiveDirectory module (RSAT)
# ============================================

# LDAP search (PowerShell AD module)
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(msDS-KeyCredentialLink=*))'
$props = @('name', 'distinguishedName', 'samAccountName', 'msDS-KeyCredentialLink')

Get-ADObject -LDAPFilter $ldapFilter -Properties $props -ErrorAction Stop |
  Select-Object name, distinguishedName, samAccountName, msDS-KeyCredentialLink |
  Sort-Object name |
  ForEach-Object { $_ }
