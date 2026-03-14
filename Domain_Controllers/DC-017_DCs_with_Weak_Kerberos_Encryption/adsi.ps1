# Check: DCs with Weak Kerberos Encryption
# Category: Domain Controllers
# Severity: high
# ID: DC-041
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : Medium
# DataSource          : LDAP
# FalsePositiveRisk   : Medium
# ─────────────────────────────────────────────

try {
    $searcher = [ADSISearcher]'(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))'
    $searcher.PageSize = 1000
    $searcher.PropertiesToLoad.Clear()
    (@('name', 'distinguishedName', 'dNSHostName', 'operatingSystem', 'msDS-SupportedEncryptionTypes', 'userAccountControl', 'objectSid', 'samAccountName') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }

    $results = $searcher.FindAll()
    Write-Host "Found $($results.Count) objects" -ForegroundColor Cyan

    $output = $results | ForEach-Object {
      $p = $_.Properties
      $encTypes = if ($p['msds-supportedencryptiontypes'].Count -gt 0) { [int]if ($p['msds-supportedencryptiontypes'] -and $p['msds-supportedencryptiontypes'].Count -gt 0) { $p['msds-supportedencryptiontypes'][0] } else { 'N/A' } } else { 0 }

      # Encryption type flags: DES=1+2, RC4=4, AES128=8, AES256=16
      $hasDES = ($encTypes -band 3) -ne 0
      $hasRC4Only = ($encTypes -eq 4)
      $hasAES = ($encTypes -band 24) -ne 0

      if ($hasDES -or ($hasRC4Only -and -not $hasAES)) {
        [PSCustomObject]@{
          Label = 'DCs with Weak Kerberos Encryption'
          Name = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0]
        UserAccountControl = if ($props['useraccountcontrol'].Count -gt 0) { $props['useraccountcontrol'][0]
    UserAccountControl = if ($p['useraccountcontrol'] -and $p['useraccountcontrol'].Count -gt 0) { $p['useraccountcontrol'][0] } else { 'N/A' } } else { 'N/A' } } else { 'N/A' }
          DistinguishedName = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
          DNSHostName = if ($p['dnshostname'] -and $p['dnshostname'].Count -gt 0) { $p['dnshostname'][0] } else { 'N/A' }
          OperatingSystem = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
          SupportedEncryptionTypes = $encTypes
          HasDES = $hasDES
          HasRC4 = ($encTypes -band 4) -ne 0
          HasAES128 = ($encTypes -band 8) -ne 0
          HasAES256 = ($encTypes -band 16) -ne 0
          Status = if ($hasDES) { "DES Enabled (Critical)" } elseif ($hasRC4Only) { "RC4 Only (Weak)" } else { "Weak Encryption" }
        }
      }
    }

    $results.Dispose()
    $searcher.Dispose()

    if ($output) { $output | Format-Table -AutoSize }


# ============================================================================
# BLOODHOUND EXPORT BLOCK
# ============================================================================
# Automatically export results to BloodHound-compatible JSON format
# ============================================================================

try {
    # Initialize session
    if (-not $env:ADSUITE_SESSION_ID) {
        $env:ADSUITE_SESSION_ID = Get-Date -Format 'yyyyMMdd_HHmmss'
        Write-Host "[BloodHound] New session: $env:ADSUITE_SESSION_ID" -ForegroundColor Cyan
    }
    
    $bhDir = "C:\ADSuite_BloodHound\SESSION_$env:ADSUITE_SESSION_ID"
    if (-not (Test-Path $bhDir)) {
        New-Item -ItemType Directory -Path $bhDir -Force | Out-Null
    }
    
    # Convert results to BloodHound format
    if ($results -and $results.Count -gt 0) {
        $bhNodes = @()
        
        foreach ($item in $results) {
            # Extract SID as ObjectIdentifier
            $objectId = if ($item.objectSid) {
                try {
                    (New-Object System.Security.Principal.SecurityIdentifier($item.objectSid, 0)).Value
                } catch {
                    $item.DistinguishedName
                }
            } else {
                $item.DistinguishedName
            }
            
            # Determine object type
            $objectType = if ($item.objectClass -contains 'user') { 'User' }
                         elseif ($item.objectClass -contains 'computer') { 'Computer' }
                         elseif ($item.objectClass -contains 'group') { 'Group' }
                         else { 'Base' }
            
            # Extract domain from DN
            $domain = if ($item.DistinguishedName -match 'DC=([^,]+)') {
                ($matches[1..($matches.Count-1)] -join '.').ToUpper()
            } else { 'UNKNOWN' }
            
            $bhNodes += @{
                ObjectIdentifier = $objectId
                ObjectType = $objectType
                Properties = @{
                    name = $item.Name
                    distinguishedname = $item.DistinguishedName
                    samaccountname = $item.samAccountName
                    domain = $domain
                    checkid = 'DC-017'
                    severity = 'high'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "DC-017_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: # Check: DCs with Weak Kerberos Encryption
# Category: Domain Controllers
# Severity: high
# ID: DC-041
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : Medium
# DataSource          : LDAP
# FalsePositiveRisk   : Medium
# ─────────────────────────────────────────────

try {
    $searcher = [ADSISearcher]'(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))'
    $searcher.PageSize = 1000
    $searcher.PropertiesToLoad.Clear()
    (@('name', 'distinguishedName', 'dNSHostName', 'operatingSystem', 'msDS-SupportedEncryptionTypes', 'userAccountControl', 'objectSid', 'samAccountName') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }

    $results = $searcher.FindAll()
    Write-Host "Found $($results.Count) objects" -ForegroundColor Cyan

    $output = $results | ForEach-Object {
      $p = $_.Properties
      $encTypes = if ($p['msds-supportedencryptiontypes'].Count -gt 0) { [int]if ($p['msds-supportedencryptiontypes'] -and $p['msds-supportedencryptiontypes'].Count -gt 0) { $p['msds-supportedencryptiontypes'][0] } else { 'N/A' } } else { 0 }

      # Encryption type flags: DES=1+2, RC4=4, AES128=8, AES256=16
      $hasDES = ($encTypes -band 3) -ne 0
      $hasRC4Only = ($encTypes -eq 4)
      $hasAES = ($encTypes -band 24) -ne 0

      if ($hasDES -or ($hasRC4Only -and -not $hasAES)) {
        [PSCustomObject]@{
          Label = 'DCs with Weak Kerberos Encryption'
          Name = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0]
        UserAccountControl = if ($props['useraccountcontrol'].Count -gt 0) { $props['useraccountcontrol'][0]
    UserAccountControl = if ($p['useraccountcontrol'] -and $p['useraccountcontrol'].Count -gt 0) { $p['useraccountcontrol'][0] } else { 'N/A' } } else { 'N/A' } } else { 'N/A' }
          DistinguishedName = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
          DNSHostName = if ($p['dnshostname'] -and $p['dnshostname'].Count -gt 0) { $p['dnshostname'][0] } else { 'N/A' }
          OperatingSystem = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
          SupportedEncryptionTypes = $encTypes
          HasDES = $hasDES
          HasRC4 = ($encTypes -band 4) -ne 0
          HasAES128 = ($encTypes -band 8) -ne 0
          HasAES256 = ($encTypes -band 16) -ne 0
          Status = if ($hasDES) { "DES Enabled (Critical)" } elseif ($hasRC4Only) { "RC4 Only (Weak)" } else { "Weak Encryption" }
        }
      }
    }

    $results.Dispose()
    $searcher.Dispose()

    if ($output) { $output | Format-Table -AutoSize }
    else { Write-Host 'No findings' -ForegroundColor Gray }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}
"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================
    else { Write-Host 'No findings' -ForegroundColor Gray }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}
