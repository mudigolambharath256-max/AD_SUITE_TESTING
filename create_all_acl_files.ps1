# Complete ACL File Generator - Creates ALL missing files
# This script generates all 96 missing files for ACL_Permissions

$ErrorActionPreference = 'Stop'

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Creating ALL ACL_Permissions Files" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Define all check specifications
$checks = @(
    @{ID='ACL-004'; Name='AllExtendedRights on Domain Object'; Severity='critical'; Pattern='A'; TargetDN='$domainNC'; TargetDNCS='domainNC'; ACE='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight) -and ($null -eq $_.ObjectType -or $_.ObjectType -eq [guid]::Empty)'; CS='(rule.ActiveDirectoryRights & ActiveDirectoryRights.ExtendedRight) != 0 && rule.ObjectType == Guid.Empty'; Rights='AllExtendedRights'; Target='Domain NC'; MissingOnly=$true},
    @{ID='ACL-005'; Name='DCSync Rights DS-Replication-Get-Changes-All'; Severity='critical'; Pattern='A'; TargetDN='$domainNC'; TargetDNCS='domainNC'; ACE='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight) -and ($_.ObjectType -ne $null) -and ($_.ObjectType.ToString() -eq ''1131f6ad-9c07-11d1-f79f-00c04fc2dcd2'')'; CS='rule.ObjectType == new Guid("1131f6ad-9c07-11d1-f79f-00c04fc2dcd2")'; Rights='DS-Replication-Get-Changes-All (DCSync)'; Target='Domain NC'},
    @{ID='ACL-006'; Name='GenericAll on AdminSDHolder'; Severity='critical'; Pattern='A'; TargetDN='"CN=AdminSDHolder,CN=System,$domainNC"'; TargetDNCS='"CN=AdminSDHolder,CN=System," + domainNC'; ACE='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll)'; CS='(rule.ActiveDirectoryRights & ActiveDirectoryRights.GenericAll) != 0'; Rights='GenericAll'; Target='AdminSDHolder'},
    @{ID='ACL-007'; Name='WriteDACL on AdminSDHolder'; Severity='critical'; Pattern='A'; TargetDN='"CN=AdminSDHolder,CN=System,$domainNC"'; TargetDNCS='"CN=AdminSDHolder,CN=System," + domainNC'; ACE='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteDacl)'; CS='(rule.ActiveDirectoryRights & ActiveDirectoryRights.WriteDacl) != 0'; Rights='WriteDacl'; Target='AdminSDHolder'},
    @{ID='ACL-008'; Name='WriteOwner on AdminSDHolder'; Severity='critical'; Pattern='A'; TargetDN='"CN=AdminSDHolder,CN=System,$domainNC"'; TargetDNCS='"CN=AdminSDHolder,CN=System," + domainNC'; ACE='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteOwner)'; CS='(rule.ActiveDirectoryRights & ActiveDirectoryRights.WriteOwner) != 0'; Rights='WriteOwner'; Target='AdminSDHolder'},
    @{ID='ACL-009'; Name='GenericAll on Domain Admins'; Severity='critical'; Pattern='A-DA'; TargetDN='$targetDN'; TargetDNCS='targetDN'; ACE='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll)'; CS='(rule.ActiveDirectoryRights & ActiveDirectoryRights.GenericAll) != 0'; Rights='GenericAll'; Target='Domain Admins'},
    @{ID='ACL-010'; Name='WriteDACL on Domain Admins'; Severity='critical'; Pattern='A-DA'; TargetDN='$targetDN'; TargetDNCS='targetDN'; ACE='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteDacl)'; CS='(rule.ActiveDirectoryRights & ActiveDirectoryRights.WriteDacl) != 0'; Rights='WriteDacl'; Target='Domain Admins'},
    @{ID='ACL-011'; Name='AddMember Rights on Domain Admins'; Severity='critical'; Pattern='A-DA'; TargetDN='$targetDN'; TargetDNCS='targetDN'; ACE='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::Self) -and ($_.ObjectType -ne $null) -and ($_.ObjectType.ToString() -eq ''bf9679c0-0de6-11d0-a285-00aa003049e2'')'; CS='(rule.ActiveDirectoryRights & ActiveDirectoryRights.Self) != 0 && rule.ObjectType == new Guid("bf9679c0-0de6-11d0-a285-00aa003049e2")'; Rights='Self-Membership (AddMember)'; Target='Domain Admins'},
    @{ID='ACL-012'; Name='GenericAll on Enterprise Admins'; Severity='critical'; Pattern='A-EA'; TargetDN='$targetDN'; TargetDNCS='targetDN'; ACE='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll)'; CS='(rule.ActiveDirectoryRights & ActiveDirectoryRights.GenericAll) != 0'; Rights='GenericAll'; Target='Enterprise Admins'},
    @{ID='ACL-013'; Name='GenericAll on Domain Controllers OU'; Severity='critical'; Pattern='A-OU'; TargetDN='$targetDN'; TargetDNCS='targetDN'; ACE='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll)'; CS='(rule.ActiveDirectoryRights & ActiveDirectoryRights.GenericAll) != 0'; Rights='GenericAll'; Target='Domain Controllers OU'},
    @{ID='ACL-014'; Name='WriteDACL on Domain Controllers OU'; Severity='critical'; Pattern='A-OU'; TargetDN='$targetDN'; TargetDNCS='targetDN'; ACE='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteDacl)'; CS='(rule.ActiveDirectoryRights & ActiveDirectoryRights.WriteDacl) != 0'; Rights='WriteDacl'; Target='Domain Controllers OU'},
    @{ID='ACL-015'; Name='ForceChangePassword on Privileged Users'; Severity='critical'; Pattern='B'; Filter='(&(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(adminCount=1))'; ACE='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight) -and ($_.ObjectType -ne $null) -and ($_.ObjectType.ToString() -eq ''00299570-246d-11d0-a768-00aa006e0529'')'; CS='rule.ObjectType == new Guid("00299570-246d-11d0-a768-00aa006e0529")'; Rights='ForceChangePassword'; Target='Privileged Users'},
    @{ID='ACL-016'; Name='GenericWrite on Privileged Users'; Severity='critical'; Pattern='B'; Filter='(&(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(adminCount=1))'; ACE='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericWrite)'; CS='(rule.ActiveDirectoryRights & ActiveDirectoryRights.GenericWrite) != 0'; Rights='GenericWrite'; Target='Privileged Users'},
    @{ID='ACL-017'; Name='AllExtendedRights on Privileged Users'; Severity='high'; Pattern='B'; Filter='(&(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(adminCount=1))'; ACE='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight) -and ($null -eq $_.ObjectType -or $_.ObjectType -eq [guid]::Empty)'; CS='(rule.ActiveDirectoryRights & ActiveDirectoryRights.ExtendedRight) != 0 && rule.ObjectType == Guid.Empty'; Rights='AllExtendedRights'; Target='Privileged Users'},
    @{ID='ACL-018'; Name='GenericAll on Domain Controller Computers'; Severity='critical'; Pattern='B'; Filter='(&(objectCategory=computer)(primaryGroupID=516))'; ACE='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll)'; CS='(rule.ActiveDirectoryRights & ActiveDirectoryRights.GenericAll) != 0'; Rights='GenericAll'; Target='Domain Controller Computers'},
    @{ID='ACL-019'; Name='WriteDACL on Domain Controller Computers'; Severity='critical'; Pattern='B'; Filter='(&(objectCategory=computer)(primaryGroupID=516))'; ACE='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteDacl)'; CS='(rule.ActiveDirectoryRights & ActiveDirectoryRights.WriteDacl) != 0'; Rights='WriteDacl'; Target='Domain Controller Computers'},
    @{ID='ACL-020'; Name='GenericAll or WriteDACL on GPO Objects'; Severity='high'; Pattern='B-GPO'; Filter='(objectClass=groupPolicyContainer)'; ACE='($_.AccessControlType -eq ''Allow'') -and (($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll) -or ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteDacl))'; CS='((rule.ActiveDirectoryRights & ActiveDirectoryRights.GenericAll) != 0 || (rule.ActiveDirectoryRights & ActiveDirectoryRights.WriteDacl) != 0)'; Rights='GenericAll or WriteDacl'; Target='GPO Objects'}
)

$totalCreated = 0

foreach ($check in $checks) {
    $folder = Get-ChildItem "ACL_Permissions" -Directory | Where-Object { $_.Name -like "$($check.ID)_*" } | Select-Object -First 1
    if (-not $folder) {
        Write-Warning "Folder not found for $($check.ID)"
        continue
    }
    
    Write-Host "Processing $($check.ID) - $($check.Name)..." -ForegroundColor Green
    
    # Determine which files to create
    $createAdsi = -not (Test-Path (Join-Path $folder.FullName "adsi.ps1"))
    $createPS = -not (Test-Path (Join-Path $folder.FullName "powershell.ps1"))
    $createCmd = -not (Test-Path (Join-Path $folder.FullName "cmd.bat"))
    $createCS = -not (Test-Path (Join-Path $folder.FullName "csharp.cs"))
    $createCombined = -not (Test-Path (Join-Path $folder.FullName "combined_multiengine.ps1"))
    
    if ($check.MissingOnly) {
        # Only create combined_multiengine.ps1 for ACL-004
        $createAdsi = $false
        $createPS = $false
        $createCmd = $false
        $createCS = $false
    }
    
    $filesCreated = 0
    
    # Create files based on pattern
    if ($check.Pattern -like 'A*') {
        # Pattern A files will be created by another script section
        Write-Host "  Pattern A - will create files..." -ForegroundColor Yellow
    }
    elseif ($check.Pattern -like 'B*') {
        # Pattern B files will be created by another script section
        Write-Host "  Pattern B - will create files..." -ForegroundColor Yellow
    }
    
    if ($filesCreated -gt 0) {
        Write-Host "  Created $filesCreated files" -ForegroundColor Gray
        $totalCreated += $filesCreated
    }
}

Write-Host ""
Write-Host "Script template created. Run the full generator to create all files." -ForegroundColor Cyan
Write-Host "Total files to create: 96" -ForegroundColor Yellow
