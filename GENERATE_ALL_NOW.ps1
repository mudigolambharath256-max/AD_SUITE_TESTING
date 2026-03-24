# MASTER FILE GENERATOR - Creates ALL 96 missing ACL files
# Run this script to generate everything at once

$ErrorActionPreference = 'Continue'

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  ACL_Permissions MASTER FILE GENERATOR" -ForegroundColor Cyan  
Write-Host "  Creating ALL missing files now..." -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$totalCreated = 0
$startTime = Get-Date

# All check definitions with complete specifications
$allChecks = @(
    @{ID='ACL-004'; Name='AllExtendedRights on Domain Object'; Sev='critical'; Pat='A'; TDN='`$domainNC'; TDNCS='domainNC'; ACE='(`$_.AccessControlType -eq ''Allow'') -and (`$_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight) -and (`$null -eq `$_.ObjectType -or `$_.ObjectType -eq [guid]::Empty)'; CS='(rule.ActiveDirectoryRights & ActiveDirectoryRights.ExtendedRight) != 0 && rule.ObjectType == Guid.Empty'; Rts='AllExtendedRights'; Tgt='Domain NC'; Flt=''; OnlyCombined=$true},
    @{ID='ACL-005'; Name='DCSync Rights DS-Replication-Get-Changes-All'; Sev='critical'; Pat='A'; TDN='`$domainNC'; TDNCS='domainNC'; ACE='(`$_.AccessControlType -eq ''Allow'') -and (`$_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight) -and (`$_.ObjectType -ne `$null) -and (`$_.ObjectType.ToString() -eq ''1131f6ad-9c07-11d1-f79f-00c04fc2dcd2'')'; CS='rule.ObjectType == new Guid("1131f6ad-9c07-11d1-f79f-00c04fc2dcd2")'; Rts='DS-Replication-Get-Changes-All (DCSync)'; Tgt='Domain NC'; Flt=''},
    @{ID='ACL-006'; Name='GenericAll on AdminSDHolder'; Sev='critical'; Pat='A'; TDN='"CN=AdminSDHolder,CN=System,`$domainNC"'; TDNCS='"CN=AdminSDHolder,CN=System," + domainNC'; ACE='(`$_.AccessControlType -eq ''Allow'') -and (`$_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll)'; CS='(rule.ActiveDirectoryRights & ActiveDirectoryRights.GenericAll) != 0'; Rts='GenericAll'; Tgt='AdminSDHolder'; Flt=''},
    @{ID='ACL-007'; Name='WriteDACL on AdminSDHolder'; Sev='critical'; Pat='A'; TDN='"CN=AdminSDHolder,CN=System,`$domainNC"'; TDNCS='"CN=AdminSDHolder,CN=System," + domainNC'; ACE='(`$_.AccessControlType -eq ''Allow'') -and (`$_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteDacl)'; CS='(rule.ActiveDirectoryRights & ActiveDirectoryRights.WriteDacl) != 0'; Rts='WriteDacl'; Tgt='AdminSDHolder'; Flt=''},
    @{ID='ACL-008'; Name='WriteOwner on AdminSDHolder'; Sev='critical'; Pat='A'; TDN='"CN=AdminSDHolder,CN=System,`$domainNC"'; TDNCS='"CN=AdminSDHolder,CN=System," + domainNC'; ACE='(`$_.AccessControlType -eq ''Allow'') -and (`$_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteOwner)'; CS='(rule.ActiveDirectoryRights & ActiveDirectoryRights.WriteOwner) != 0'; Rts='WriteOwner'; Tgt='AdminSDHolder'; Flt=''},
    @{ID='ACL-009'; Name='GenericAll on Domain Admins'; Sev='critical'; Pat='A-DA'; TDN='`$targetDN'; TDNCS='targetDN'; ACE='(`$_.AccessControlType -eq ''Allow'') -and (`$_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll)'; CS='(rule.ActiveDirectoryRights & ActiveDirectoryRights.GenericAll) != 0'; Rts='GenericAll'; Tgt='Domain Admins'; Flt=''},
    @{ID='ACL-010'; Name='WriteDACL on Domain Admins'; Sev='critical'; Pat='A-DA'; TDN='`$targetDN'; TDNCS='targetDN'; ACE='(`$_.AccessControlType -eq ''Allow'') -and (`$_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteDacl)'; CS='(rule.ActiveDirectoryRights & ActiveDirectoryRights.WriteDacl) != 0'; Rts='WriteDacl'; Tgt='Domain Admins'; Flt=''},
    @{ID='ACL-011'; Name='AddMember Rights on Domain Admins'; Sev='critical'; Pat='A-DA'; TDN='`$targetDN'; TDNCS='targetDN'; ACE='(`$_.AccessControlType -eq ''Allow'') -and (`$_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::Self) -and (`$_.ObjectType -ne `$null) -and (`$_.ObjectType.ToString() -eq ''bf9679c0-0de6-11d0-a285-00aa003049e2'')'; CS='(rule.ActiveDirectoryRights & ActiveDirectoryRights.Self) != 0 && rule.ObjectType == new Guid("bf9679c0-0de6-11d0-a285-00aa003049e2")'; Rts='Self-Membership (AddMember)'; Tgt='Domain Admins'; Flt=''},
    @{ID='ACL-012'; Name='GenericAll on Enterprise Admins'; Sev='critical'; Pat='A-EA'; TDN='`$targetDN'; TDNCS='targetDN'; ACE='(`$_.AccessControlType -eq ''Allow'') -and (`$_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll)'; CS='(rule.ActiveDirectoryRights & ActiveDirectoryRights.GenericAll) != 0'; Rts='GenericAll'; Tgt='Enterprise Admins'; Flt=''},
    @{ID='ACL-013'; Name='GenericAll on Domain Controllers OU'; Sev='critical'; Pat='A-OU'; TDN='`$targetDN'; TDNCS='targetDN'; ACE='(`$_.AccessControlType -eq ''Allow'') -and (`$_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll)'; CS='(rule.ActiveDirectoryRights & ActiveDirectoryRights.GenericAll) != 0'; Rts='GenericAll'; Tgt='Domain Controllers OU'; Flt=''},
    @{ID='ACL-014'; Name='WriteDACL on Domain Controllers OU'; Sev='critical'; Pat='A-OU'; TDN='`$targetDN'; TDNCS='targetDN'; ACE='(`$_.AccessControlType -eq ''Allow'') -and (`$_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteDacl)'; CS='(rule.ActiveDirectoryRights & ActiveDirectoryRights.WriteDacl) != 0'; Rts='WriteDacl'; Tgt='Domain Controllers OU'; Flt=''},
    @{ID='ACL-015'; Name='ForceChangePassword on Privileged Users'; Sev='critical'; Pat='B'; TDN=''; TDNCS=''; ACE='(`$_.AccessControlType -eq ''Allow'') -and (`$_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight) -and (`$_.ObjectType -ne `$null) -and (`$_.ObjectType.ToString() -eq ''00299570-246d-11d0-a768-00aa006e0529'')'; CS='rule.ObjectType == new Guid("00299570-246d-11d0-a768-00aa006e0529")'; Rts='ForceChangePassword'; Tgt='Privileged Users'; Flt='(&(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(adminCount=1))'},
    @{ID='ACL-016'; Name='GenericWrite on Privileged Users'; Sev='critical'; Pat='B'; TDN=''; TDNCS=''; ACE='(`$_.AccessControlType -eq ''Allow'') -and (`$_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericWrite)'; CS='(rule.ActiveDirectoryRights & ActiveDirectoryRights.GenericWrite) != 0'; Rts='GenericWrite'; Tgt='Privileged Users'; Flt='(&(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(adminCount=1))'},
    @{ID='ACL-017'; Name='AllExtendedRights on Privileged Users'; Sev='high'; Pat='B'; TDN=''; TDNCS=''; ACE='(`$_.AccessControlType -eq ''Allow'') -and (`$_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight) -and (`$null -eq `$_.ObjectType -or `$_.ObjectType -eq [guid]::Empty)'; CS='(rule.ActiveDirectoryRights & ActiveDirectoryRights.ExtendedRight) != 0 && rule.ObjectType == Guid.Empty'; Rts='AllExtendedRights'; Tgt='Privileged Users'; Flt='(&(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(adminCount=1))'},
    @{ID='ACL-018'; Name='GenericAll on Domain Controller Computers'; Sev='critical'; Pat='B'; TDN=''; TDNCS=''; ACE='(`$_.AccessControlType -eq ''Allow'') -and (`$_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll)'; CS='(rule.ActiveDirectoryRights & ActiveDirectoryRights.GenericAll) != 0'; Rts='GenericAll'; Tgt='Domain Controller Computers'; Flt='(&(objectCategory=computer)(primaryGroupID=516))'},
    @{ID='ACL-019'; Name='WriteDACL on Domain Controller Computers'; Sev='critical'; Pat='B'; TDN=''; TDNCS=''; ACE='(`$_.AccessControlType -eq ''Allow'') -and (`$_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteDacl)'; CS='(rule.ActiveDirectoryRights & ActiveDirectoryRights.WriteDacl) != 0'; Rts='WriteDacl'; Tgt='Domain Controller Computers'; Flt='(&(objectCategory=computer)(primaryGroupID=516))'},
    @{ID='ACL-020'; Name='GenericAll or WriteDACL on GPO Objects'; Sev='high'; Pat='B-GPO'; TDN=''; TDNCS=''; ACE='(`$_.AccessControlType -eq ''Allow'') -and ((`$_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll) -or (`$_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteDacl))'; CS='((rule.ActiveDirectoryRights & ActiveDirectoryRights.GenericAll) != 0 || (rule.ActiveDirectoryRights & ActiveDirectoryRights.WriteDacl) != 0)'; Rts='GenericAll or WriteDacl'; Tgt='GPO Objects'; Flt='(objectClass=groupPolicyContainer)'}
)

Write-Host "Processing $($allChecks.Count) checks..." -ForegroundColor Yellow
Write-Host ""

# Import the file generation templates
. "$PSScriptRoot\acl_file_templates.ps1"

foreach ($c in $allChecks) {
    $folder = Get-ChildItem "ACL_Permissions" -Directory | Where-Object { $_.Name -like "$($c.ID)_*" } | Select-Object -First 1
    if (-not $folder) {
        Write-Warning "Folder not found for $($c.ID)"
        continue
    }
    
    Write-Host "[$($c.ID)] $($c.Name)" -ForegroundColor Green
    
    $created = Create-AllFilesForCheck -Check $c -FolderPath $folder.FullName
    $totalCreated += $created
    
    Write-Host "  Created $created file(s)" -ForegroundColor Gray
}

$elapsed = (Get-Date) - $startTime

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  GENERATION COMPLETE!" -ForegroundColor Green
Write-Host "  Total files created: $totalCreated" -ForegroundColor Green
Write-Host "  Time: $([math]::Round($elapsed.TotalSeconds, 2)) seconds" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Cyan

# Final verification
Write-Host ""
Write-Host "Verifying file count..." -ForegroundColor Yellow
$ps1 = (Get-ChildItem "ACL_Permissions" -Recurse -Filter "*.ps1").Count
$cs = (Get-ChildItem "ACL_Permissions" -Recurse -Filter "*.cs").Count
$bat = (Get-ChildItem "ACL_Permissions" -Recurse -Filter "*.bat").Count
$total = $ps1 + $cs + $bat

Write-Host "PowerShell (.ps1): $ps1 / 60" -ForegroundColor $(if ($ps1 -eq 60) { 'Green' } else { 'Yellow' })
Write-Host "C# (.cs): $cs / 20" -ForegroundColor $(if ($cs -eq 20) { 'Green' } else { 'Yellow' })
Write-Host "Batch (.bat): $bat / 20" -ForegroundColor $(if ($bat -eq 20) { 'Green' } else { 'Yellow' })
Write-Host "TOTAL: $total / 100" -ForegroundColor $(if ($total -eq 100) { 'Green' } else { 'Yellow' })
