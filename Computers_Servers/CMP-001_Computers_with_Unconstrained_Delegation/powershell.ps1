# Check: Computers with Unconstrained Delegation
# Category: Computers & Servers
# Severity: critical
# ID: CMP-001
# Requirements: ActiveDirectory module (RSAT)
# ============================================

# LDAP search (PowerShell AD module)
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(userAccountControl:1.2.840.113556.1.4.803:=524288)(!(primaryGroupID=516)))'
$props = @('name', 'distinguishedName', 'samAccountName', 'operatingSystem', 'userAccountControl')

Get-ADObject -LDAPFilter $ldapFilter -Properties $props -ErrorAction Stop |
  Select-Object name, distinguishedName, samAccountName, operatingSystem, userAccountControl |
  Sort-Object name |
  ForEach-Object { $_ }
