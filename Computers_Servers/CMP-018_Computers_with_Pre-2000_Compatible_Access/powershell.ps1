# Check: Computers with Pre-2000 Compatible Access
# Category: Computers & Servers
# Severity: medium
# ID: CMP-018
# Requirements: ActiveDirectory module (RSAT)
# ============================================

# LDAP search (PowerShell AD module)
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(memberOf:1.2.840.113556.1.4.1941:=CN=Pre-Windows 2000 Compatible Access,CN=Builtin,*))'
$props = @('name', 'distinguishedName', 'samAccountName', 'memberOf')

Get-ADObject -LDAPFilter $ldapFilter -Properties $props -ErrorAction Stop |
  Select-Object name, distinguishedName, samAccountName, memberOf |
  Sort-Object name |
  ForEach-Object { $_ }
