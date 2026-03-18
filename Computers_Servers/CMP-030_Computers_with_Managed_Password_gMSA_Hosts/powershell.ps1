# Check: Computers with Managed Password (gMSA Hosts)
# Category: Computers & Servers
# Severity: info
# ID: CMP-030
# Requirements: ActiveDirectory module (RSAT)
# ============================================

# LDAP search (PowerShell AD module)
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectClass=msDS-GroupManagedServiceAccount)(msDS-HostServiceAccount=*))'
$props = @('name', 'distinguishedName', 'samAccountName', 'msDS-HostServiceAccount')

Get-ADObject -LDAPFilter $ldapFilter -Properties $props -ErrorAction Stop |
  Select-Object name, distinguishedName, samAccountName, msDS-HostServiceAccount |
  Sort-Object name |
  ForEach-Object { $_ }
