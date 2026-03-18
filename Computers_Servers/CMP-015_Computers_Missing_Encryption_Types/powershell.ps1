# Check: Computers Missing Encryption Types
# Category: Computers & Servers
# Severity: medium
# ID: CMP-015
# Requirements: ActiveDirectory module (RSAT)
# ============================================

# LDAP search (PowerShell AD module)
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(!(msDS-SupportedEncryptionTypes=*)))'
$props = @('name', 'distinguishedName', 'samAccountName', 'operatingSystem')

Get-ADObject -LDAPFilter $ldapFilter -Properties $props -ErrorAction Stop |
  Select-Object name, distinguishedName, samAccountName, operatingSystem |
  Sort-Object name |
  ForEach-Object { $_ }
