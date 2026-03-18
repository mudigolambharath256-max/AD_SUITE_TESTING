# Check: Computers with Service Principal Names
# Category: Computers & Servers
# Severity: info
# ID: CMP-024
# Requirements: ActiveDirectory module (RSAT)
# ============================================

# LDAP search (PowerShell AD module)
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(servicePrincipalName=*))'
$props = @('name', 'distinguishedName', 'samAccountName', 'servicePrincipalName')

Get-ADObject -LDAPFilter $ldapFilter -Properties $props -ErrorAction Stop |
  Select-Object name, distinguishedName, samAccountName, servicePrincipalName |
  Sort-Object name |
  ForEach-Object { $_ }
