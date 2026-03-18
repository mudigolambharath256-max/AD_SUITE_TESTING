# Check: Computers with LAPS Deployed
# Category: Computers & Servers
# Severity: info
# ID: CMP-004
# Requirements: ActiveDirectory module (RSAT)
# ============================================

# LDAP search (PowerShell AD module)
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(ms-Mcs-AdmPwd=*))'
$props = @('name', 'distinguishedName', 'samAccountName', 'ms-Mcs-AdmPwdExpirationTime', 'operatingSystem')

Get-ADObject -LDAPFilter $ldapFilter -Properties $props -ErrorAction Stop |
  Select-Object name, distinguishedName, samAccountName, ms-Mcs-AdmPwdExpirationTime, operatingSystem |
  Sort-Object name |
  ForEach-Object { $_ }
