# Check: Computers Created in Last 7 Days
# Category: Computers & Servers
# Severity: info
# ID: CMP-019
# Requirements: ActiveDirectory module (RSAT)
# ============================================

# LDAP search (PowerShell AD module)
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))'
$props = @('name', 'distinguishedName', 'samAccountName', 'whenCreated', 'operatingSystem')

Get-ADObject -LDAPFilter $ldapFilter -Properties $props -ErrorAction Stop |
  Select-Object name, distinguishedName, samAccountName, whenCreated, operatingSystem |
  Sort-Object name |
  ForEach-Object { $_ }
