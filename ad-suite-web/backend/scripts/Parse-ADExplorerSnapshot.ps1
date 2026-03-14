[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$SnapshotPath,
  [Parameter(Mandatory)][string]$OutputDir,
  [string]$ConvertExePath = ''
)

Set-StrictMode -Off
$ErrorActionPreference = 'Stop'

function Write-Progress-Message($msg) {
  Write-Host $msg
}

# ── Helper: read null-terminated UTF-16LE string from BinaryReader ──────────
function Read-WString([System.IO.BinaryReader]$reader) {
  $chars = [System.Collections.Generic.List[char]]::new()
  while ($true) {
    try {
      $b1 = $reader.ReadByte()
      $b2 = $reader.ReadByte()
    } catch { break }
    if ($b1 -eq 0 -and $b2 -eq 0) { break }
    $chars.Add([char](($b2 -shl 8) -bor $b1))
  }
  return -join $chars
}

# ── Helper: convert Windows FILETIME Int64 to Unix timestamp ────────────────
function Convert-FiletimeToUnix([Int64]$ft) {
  if ($ft -le 0) { return -1 }
  try {
    $epoch = [DateTime]::new(1601,1,1,0,0,0,[System.DateTimeKind]::Utc)
    $dt = $epoch.AddTicks($ft)
    return [long]($dt - [DateTime]::UnixEpoch).TotalSeconds
  } catch { return -1 }
}

# ── Helper: derive domain FQDN from DistinguishedName ───────────────────────
function Get-DomainFromDN([string]$dn) {
  $parts = $dn -split ',' | Where-Object { $_ -match '^DC=' }
  return ($parts | ForEach-Object { $_ -replace '^DC=','' }) -join '.'
}

# ── Helper: compute objectIdentifier from objectSid ─────────────────────────
function Format-Sid([byte[]]$bytes) {
  if (-not $bytes -or $bytes.Length -lt 8) { return $null }
  try {
    $sid = New-Object System.Security.Principal.SecurityIdentifier($bytes, 0)
    return $sid.Value
  } catch { return $null }
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

# ═══════════════════════════════════════════════════════════════════════════
# TRACK 1: convertsnapshot.exe (pre-built binary, no Python needed)
# ═══════════════════════════════════════════════════════════════════════════

if ($ConvertExePath -and (Test-Path $ConvertExePath)) {
  Write-Progress-Message "[Track 1] Using convertsnapshot.exe at: $ConvertExePath"

  $result = & $ConvertExePath --output "$OutputDir\bloodhound.tar.gz" $SnapshotPath 2>&1
  Write-Progress-Message $result

  # Extract tar.gz if produced (convertsnapshot outputs a .tar.gz of JSON files)
  $tarFile = "$OutputDir\bloodhound.tar.gz"
  if (Test-Path $tarFile) {
    # PowerShell 5+ can use tar.exe (bundled with Windows 10+)
    $tarExe = (Get-Command tar.exe -ErrorAction SilentlyContinue)?.Source
    if ($tarExe) {
      & $tarExe -xzf $tarFile -C $OutputDir
      Write-Progress-Message "[Track 1] Extracted BloodHound JSON files to $OutputDir"
    }
  }

  # Find the extracted JSON files and build the unified graph.json
  $jsonFiles = Get-ChildItem -Path $OutputDir -Filter '*.json' -Recurse
  $graphData = Build-GraphFromBloodHoundFiles $jsonFiles
  $graphData | ConvertTo-Json -Depth 10 -Compress | Set-Content "$OutputDir\graph.json" -Encoding UTF8
  Write-Progress-Message "[Track 1] graph.json written"

  # Emit summary to stdout for backend to parse
  Write-Output "SUMMARY:$(($graphData.nodes).Count) nodes, $(($graphData.edges).Count) edges"
  exit 0
}

# ═══════════════════════════════════════════════════════════════════════════
# TRACK 2: Pure PowerShell BinaryReader parser (no external tools)
# ═══════════════════════════════════════════════════════════════════════════

Write-Progress-Message "[Track 2] Parsing binary snapshot with PowerShell BinaryReader..."
Write-Progress-Message "File: $SnapshotPath ($('{0:N2}' -f ((Get-Item $SnapshotPath).Length / 1MB)) MB)"

$stream = [System.IO.File]::OpenRead($SnapshotPath)
$reader = New-Object System.IO.BinaryReader($stream, [System.Text.Encoding]::Unicode)

try {
  # ── Read and validate header ─────────────────────────────────────────────
  $magic = $reader.ReadUInt32()
  if ($magic -ne 0x09031122) {
    Write-Warning "Unexpected magic: 0x$($magic.ToString('X8')). Proceeding anyway."
  }

  $flags = $reader.ReadUInt32()
  $serverName = Read-WString $reader
  $timestamp = $reader.ReadInt64()
  $mappingOffset = $reader.ReadUInt32()
  $objectCount = $reader.ReadUInt32()

  $snapshotTime = Convert-FiletimeToUnix $timestamp
  Write-Progress-Message "Server: $serverName | Objects: $objectCount | Timestamp: $snapshotTime"

  # ── Read properties table (attribute name index) ─────────────────────────
  # Properties are stored at a known location after the header.
  # Each property: DWORD propIndex, then null-terminated UTF-16LE name
  $propertyCount = $reader.ReadUInt32()
  Write-Progress-Message "Reading $propertyCount attribute definitions..."

  $propNames = @{}  # index → attribute name
  for ($i = 0; $i -lt $propertyCount; $i++) {
    try {
      $propIdx  = $reader.ReadUInt32()
      $propType = $reader.ReadUInt32()
      $propName = Read-WString $reader
      $propNames[$propIdx] = $propName
    } catch { break }
  }

  # ── Read classes table ────────────────────────────────────────────────────
  $classCount = $reader.ReadUInt32()
  $classNames = @{}
  for ($i = 0; $i -lt $classCount; $i++) {
    try {
      $classIdx  = $reader.ReadUInt32()
      $className = Read-WString $reader
      $classNames[$classIdx] = $className
    } catch { break }
  }
  Write-Progress-Message "Found $classCount object classes"

  # ── Parse LDAP objects ────────────────────────────────────────────────────
  # Each object: DWORD attrCount, then attrCount attribute records
  # Each attribute record: DWORD propIndex, DWORD valueCount, values...
  # Each value: DWORD syntaxType, data (type-dependent)

  $users = [System.Collections.Generic.List[object]]::new()
  $groups = [System.Collections.Generic.List[object]]::new()
  $computers = [System.Collections.Generic.List[object]]::new()
  $domains = [System.Collections.Generic.List[object]]::new()
  $ous = [System.Collections.Generic.List[object]]::new()
  $allObjects = [System.Collections.Generic.List[object]]::new()

  for ($objIdx = 0; $objIdx -lt $objectCount; $objIdx++) {
    try {
      $attrCount = $reader.ReadUInt32()
      $obj = @{}

      for ($a = 0; $a -lt $attrCount; $a++) {
        $propIdx    = $reader.ReadUInt32()
        $valueCount = $reader.ReadUInt32()
        $propName   = if ($propNames.ContainsKey($propIdx)) { $propNames[$propIdx] } else { "attr_$propIdx" }
        $values = @()

        for ($v = 0; $v -lt $valueCount; $v++) {
          $syntax = $reader.ReadUInt32()
          switch ($syntax) {
            0x00080001 { # DN string (UTF-16LE)
              $val = Read-WString $reader
              $values += $val
            }
            0x00080002 { # Case-insensitive string
              $val = Read-WString $reader
              $values += $val
            }
            0x00080003 { # Printable string
              $val = Read-WString $reader
              $values += $val
            }
            0x00080004 { # Numeric string
              $val = Read-WString $reader
              $values += $val
            }
            0x00080005 { # IA5 string
              $val = Read-WString $reader
              $values += $val
            }
            0x00080006 { # UTC time string
              $val = Read-WString $reader
              $values += $val
            }
            0x00080007 { # Generalized time string
              $val = Read-WString $reader
              $values += $val
            }
            0x00020001 { # Integer
              $val = $reader.ReadInt32()
              $values += $val
            }
            0x00020002 { # Large integer (Int64)
              $val = $reader.ReadInt64()
              $values += $val
            }
            0x00010001 { # Boolean
              $val = ($reader.ReadInt32() -ne 0)
              $values += $val
            }
            0x00090001 { # OctetString (raw bytes) — read length + bytes
              $byteLen = $reader.ReadUInt32()
              $rawBytes = $reader.ReadBytes($byteLen)
              # Try to interpret as SID if it looks like one
              if ($propName -match 'Sid' -and $rawBytes.Length -ge 8) {
                try {
                  $sid = New-Object System.Security.Principal.SecurityIdentifier($rawBytes, 0)
                  $values += $sid.Value
                } catch {
                  $values += [Convert]::ToBase64String($rawBytes)
                }
              } else {
                $values += [Convert]::ToBase64String($rawBytes)
              }
            }
            default {
              # Unknown syntax — try to read as wstring, skip on failure
              try {
                $val = Read-WString $reader
                $values += $val
              } catch {
                $values += "<unknown:0x$($syntax.ToString('X8'))>"
                break
              }
            }
          }
        }

        if ($values.Count -eq 1) { $obj[$propName] = $values[0] }
        elseif ($values.Count -gt 1) { $obj[$propName] = $values }
      }

      $allObjects.Add($obj)

      # Classify by objectClass
      $objClass = $obj['objectClass']
      if (-not $objClass) { continue }
      $classes = if ($objClass -is [array]) { $objClass } else { @($objClass) }

      if ($classes -contains 'user' -and $classes -notcontains 'computer') {
        $users.Add($obj)
      } elseif ($classes -contains 'group') {
        $groups.Add($obj)
      } elseif ($classes -contains 'computer') {
        $computers.Add($obj)
      } elseif ($classes -contains 'domain') {
        $domains.Add($obj)
      } elseif ($classes -contains 'organizationalUnit') {
        $ous.Add($obj)
      }

      if (($objIdx + 1) % 500 -eq 0) {
        Write-Progress-Message "  Parsed $($objIdx+1)/$objectCount objects..."
      }
    } catch {
      Write-Warning "Error parsing object $objIdx`: $_"
      continue
    }
  }
} finally {
  $reader.Close()
  $stream.Close()
}

Write-Progress-Message "Parsed: $($users.Count) users, $($groups.Count) groups, $($computers.Count) computers, $($domains.Count) domains, $($ous.Count) OUs"

# ── Transform to BloodHound JSON v4 format ──────────────────────────────────

$domainFqdn = if ($domains.Count -gt 0) {
  Get-DomainFromDN ($domains[0]['distinguishedName'] ?? '')
} else { $serverName }

$domainFqdn = $domainFqdn.ToUpper()

# ── Users ────────────────────────────────────────────────────────────────────
function Convert-ToBloodHoundUser($u, $domain) {
  $dn = $u['distinguishedName'] ?? ''
  $sam = $u['sAMAccountName'] ?? ''
  $sid = $u['objectSid'] ?? ''
  $uac = [int]($u['userAccountControl'] ?? 0)
  $name = if ($sam) { "$($sam.ToUpper())@$domain" } else { $dn }

  @{
    ObjectIdentifier = $sid
    Properties = @{
      name                   = $name
      domain                 = $domain
      distinguishedname      = $dn
      samaccountname         = $sam
      enabled                = -not [bool]($uac -band 0x2)
      admincount             = [bool]($u['adminCount'] ?? 0)
      description            = $u['description'] ?? ''
      displayname            = $u['displayName'] ?? ''
      email                  = $u['mail'] ?? ''
      title                  = $u['title'] ?? ''
      lastlogon              = Convert-FiletimeToUnix ($u['lastLogon'] ?? 0)
      lastlogontimestamp     = Convert-FiletimeToUnix ($u['lastLogonTimestamp'] ?? 0)
      pwdlastset             = Convert-FiletimeToUnix ($u['pwdLastSet'] ?? 0)
      pwdneverexpires        = [bool]($uac -band 0x10000)
      dontreqpreauth         = [bool]($uac -band 0x400000)
      passwordnotreqd        = [bool]($uac -band 0x20)
      sensitive              = [bool]($uac -band 0x100000)
      unconstraineddelegation = [bool]($uac -band 0x80000)
      trustedtoauth          = [bool]($uac -band 0x1000000)
      hasspn                 = ($u['servicePrincipalName'] -ne $null)
      serviceprincipalnames  = @($u['servicePrincipalName'] ?? @())
      objectid               = $sid
    }
    Aces         = @()
    SPNTargets   = @()
    IsACLProtected = $false
    ContainedBy  = $null
  }
}

$bhUsers = $users | ForEach-Object { Convert-ToBloodHoundUser $_ $domainFqdn }

# ── Groups ───────────────────────────────────────────────────────────────────
$bhGroups = $groups | ForEach-Object {
  $g = $_
  $dn = $g['distinguishedName'] ?? ''
  $sid = $g['objectSid'] ?? ''
  $cn = $g['cn'] ?? ($g['name'] ?? '')
  @{
    ObjectIdentifier = $sid
    Properties = @{
      name          = "$($cn.ToUpper())@$domainFqdn"
      domain        = $domainFqdn
      distinguishedname = $dn
      samaccountname = $g['sAMAccountName'] ?? ''
      admincount    = [bool]($g['adminCount'] ?? 0)
      description   = $g['description'] ?? ''
      objectid      = $sid
    }
    Members    = @($g['member'] ?? @() | ForEach-Object { @{ ObjectIdentifier = $_; ObjectType = 'Base' } })
    Aces       = @()
    IsACLProtected = $false
  }
}

# ── Computers ────────────────────────────────────────────────────────────────
$bhComputers = $computers | ForEach-Object {
  $c = $_
  $dn = $c['distinguishedName'] ?? ''
  $sid = $c['objectSid'] ?? ''
  $cn = $c['cn'] ?? ''
  $uac = [int]($c['userAccountControl'] ?? 0)
  @{
    ObjectIdentifier = $sid
    Properties = @{
      name              = "$($cn.ToUpper()).$domainFqdn"
      domain            = $domainFqdn
      distinguishedname = $dn
      samaccountname    = $c['sAMAccountName'] ?? ''
      enabled           = -not [bool]($uac -band 0x2)
      unconstraineddelegation = [bool]($uac -band 0x80000)
      operatingsystem   = $c['operatingSystem'] ?? ''
      description       = $c['description'] ?? ''
      lastlogon         = Convert-FiletimeToUnix ($c['lastLogon'] ?? 0)
      lastlogontimestamp = Convert-FiletimeToUnix ($c['lastLogonTimestamp'] ?? 0)
      objectid          = $sid
      haslaps           = ($c['ms-mcs-admpwd'] -ne $null)
    }
    Aces           = @()
    Sessions       = @()
    LocalAdmins    = @()
    RemoteDesktopUsers = @()
    DcomUsers      = @()
    PSRemoteUsers  = @()
    IsACLProtected = $false
  }
}

# ── Domains ──────────────────────────────────────────────────────────────────
$bhDomains = $domains | ForEach-Object {
  $d = $_
  $sid = $d['objectSid'] ?? "S-1-5-21-UNKNOWN"
  @{
    ObjectIdentifier = $sid
    Properties = @{
      name              = $domainFqdn
      domain            = $domainFqdn
      distinguishedname = $d['distinguishedName'] ?? ''
      objectid          = $sid
      description       = $d['description'] ?? ''
      functionallevel   = [int]($d['msDS-Behavior-Version'] ?? 0)
    }
    Aces       = @()
    Trusts     = @()
    IsACLProtected = $false
  }
}

# ── Write BloodHound JSON files ───────────────────────────────────────────────

function Write-BHFile($type, $data) {
  $out = @{
    meta = @{ type = $type; count = $data.Count; version = 4 }
    data = $data
  }
  $out | ConvertTo-Json -Depth 15 -Compress | 
    Set-Content "$OutputDir\${domainFqdn}_${type}.json" -Encoding UTF8
  Write-Progress-Message "  Written: ${type}.json ($($data.Count) objects)"
}

Write-Progress-Message "Writing BloodHound JSON files..."
Write-BHFile 'users'     $bhUsers
Write-BHFile 'groups'    $bhGroups
Write-BHFile 'computers' $bhComputers
Write-BHFile 'domains'   $bhDomains

# ── Build unified graph.json for the graph visualiser (Addition B) ───────────

function Build-GraphFromAllObjects($users, $groups, $computers, $domains, $ous, $allObjects) {
  $nodes = [System.Collections.Generic.List[object]]::new()
  $edges = [System.Collections.Generic.List[object]]::new()
  $seen  = @{}

  function Add-Node($id, $label, $type, $props) {
    if (-not $id -or $seen.ContainsKey($id)) { return }
    $seen[$id] = $true
    $nodes.Add(@{ id = $id; label = $label; type = $type; properties = $props })
  }

  # Add domain node
  foreach ($d in $domains) {
    $sid = $d['objectSid'] ?? "domain-$domainFqdn"
    Add-Node $sid $domainFqdn 'Domain' @{ dn = $d['distinguishedName'] ?? '' }
  }

  # Add user nodes
  foreach ($u in $users) {
    $sid = $u['objectSid'] ?? $null
    if (-not $sid) { continue }
    $sam = $u['sAMAccountName'] ?? ''
    $uac = [int]($u['userAccountControl'] ?? 0)
    Add-Node $sid "$sam@$domainFqdn" 'User' @{
      enabled    = -not [bool]($uac -band 0x2)
      admincount = [bool]($u['adminCount'] ?? 0)
      hasspn     = ($u['servicePrincipalName'] -ne $null)
      dn         = $u['distinguishedName'] ?? ''
    }
  }

  # Add group nodes + MemberOf edges
  foreach ($g in $groups) {
    $sid = $g['objectSid'] ?? $null
    if (-not $sid) { continue }
    $cn = $g['cn'] ?? ($g['name'] ?? 'Unknown')
    Add-Node $sid "$cn@$domainFqdn" 'Group' @{
      admincount = [bool]($g['adminCount'] ?? 0)
      dn         = $g['distinguishedName'] ?? ''
    }

    # Member → Group edges
    $members = $g['member'] ?? @()
    if ($members -isnot [array]) { $members = @($members) }
    foreach ($memberDN in $members) {
      # Look up the member SID from allObjects
      $memberObj = $allObjects | Where-Object { $_['distinguishedName'] -eq $memberDN } | Select-Object -First 1
      $memberSid = $memberObj?['objectSid']
      if ($memberSid) {
        $edges.Add(@{ source = $memberSid; target = $sid; type = 'MemberOf'; label = 'MemberOf' })
      }
    }
  }

  # Add computer nodes
  foreach ($c in $computers) {
    $sid = $c['objectSid'] ?? $null
    if (-not $sid) { continue }
    $cn = $c['cn'] ?? 'Unknown'
    $uac = [int]($c['userAccountControl'] ?? 0)
    Add-Node $sid "$cn.$domainFqdn" 'Computer' @{
      enabled  = -not [bool]($uac -band 0x2)
      os       = $c['operatingSystem'] ?? ''
      dn       = $c['distinguishedName'] ?? ''
    }
  }

  return @{ nodes = @($nodes); edges = @($edges); meta = @{ domain = $domainFqdn; server = $serverName; snapshotTime = $snapshotTime; nodeCount = $nodes.Count; edgeCount = $edges.Count } }
}

$graphData = Build-GraphFromAllObjects $users $groups $computers $domains $ous $allObjects
$graphData | ConvertTo-Json -Depth 10 -Compress | Set-Content "$OutputDir\graph.json" -Encoding UTF8

Write-Progress-Message "graph.json written: $($graphData.nodes.Count) nodes, $($graphData.edges.Count) edges"
Write-Output "SUMMARY:$($graphData.nodes.Count) nodes, $($graphData.edges.Count) edges, $($users.Count) users, $($groups.Count) groups, $($computers.Count) computers"
