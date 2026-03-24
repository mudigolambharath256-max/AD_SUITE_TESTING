# Complete ACL_Permissions File Generator
# Generates ALL 100 files (20 checks × 5 engines) according to KIRO_ACL_PERMISSIONS_PROMPT.md
# This script creates every file programmatically with exact specifications

$ErrorActionPreference = 'Stop'

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "ACL_Permissions Complete File Generator" -ForegroundColor Cyan
Write-Host "Creating 100 files (20 checks × 5 engines)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Define all 20 checks with complete specifications
$allChecks = @(
    # Pattern A checks (ACL-001 through ACL-014) - Fixed Target
    @{
        ID='ACL-001'; Name='GenericAll on Domain Object'; Folder='ACL-001_GenericAll_on_Domain_Object'
        Severity='critical'; Pattern='A'; TargetDN='$domainNC'; TargetDNCS='domainNC'
        ACECondition='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll)'
        CSCondition='(rule.ActiveDirectoryRights & ActiveDirectoryRights.GenericAll) != 0'
        Rights='GenericAll'; Target='Domain NC object'; SearchBase=''; Filter=''
    },
    @{
        ID='ACL-002'; Name='WriteDACL on Domain Object'; Folder='ACL-002_WriteDACL_on_Domain_Object'
        Severity='critical'; Pattern='A'; TargetDN='$domainNC'; TargetDNCS='domainNC'
        ACECondition='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteDacl)'
        CSCondition='(rule.ActiveDirectoryRights & ActiveDirectoryRights.WriteDacl) != 0'
        Rights='WriteDacl'; Target='Domain NC object'; SearchBase=''; Filter=''
    },
    @{
        ID='ACL-003'; Name='WriteOwner on Domain Object'; Folder='ACL-003_WriteOwner_on_Domain_Object'
        Severity='critical'; Pattern='A'; TargetDN='$domainNC'; TargetDNCS='domainNC'
        ACECondition='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteOwner)'
        CSCondition='(rule.ActiveDirectoryRights & ActiveDirectoryRights.WriteOwner) != 0'
        Rights='WriteOwner'; Target='Domain NC object'; SearchBase=''; Filter=''
    },
    @{
        ID='ACL-004'; Name='AllExtendedRights on Domain Object'; Folder='ACL-004_AllExtendedRights_on_Domain_Object'
        Severity='critical'; Pattern='A'; TargetDN='$domainNC'; TargetDNCS='domainNC'
        ACECondition='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight) -and ($null -eq $_.ObjectType -or $_.ObjectType -eq [guid]::Empty)'
        CSCondition='(rule.ActiveDirectoryRights & ActiveDirectoryRights.ExtendedRight) != 0 && rule.ObjectType == Guid.Empty'
        Rights='AllExtendedRights'; Target='Domain NC object'; SearchBase=''; Filter=''
    },
    @{
        ID='ACL-005'; Name='DCSync Rights DS-Replication-Get-Changes-All'; Folder='ACL-005_DCSync_Rights_DS_Replication_Get_Changes_All'
        Severity='critical'; Pattern='A'; TargetDN='$domainNC'; TargetDNCS='domainNC'
        ACECondition='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight) -and ($_.ObjectType -ne $null) -and ($_.ObjectType.ToString() -eq ''1131f6ad-9c07-11d1-f79f-00c04fc2dcd2'')'
        CSCondition='rule.ObjectType == new Guid("1131f6ad-9c07-11d1-f79f-00c04fc2dcd2")'
        Rights='DS-Replication-Get-Changes-All (DCSync)'; Target='Domain NC object'; SearchBase=''; Filter=''
    },
    @{
        ID='ACL-006'; Name='GenericAll on AdminSDHolder'; Folder='ACL-006_GenericAll_on_AdminSDHolder'
        Severity='critical'; Pattern='A'; TargetDN='"CN=AdminSDHolder,CN=System,$domainNC"'; TargetDNCS='"CN=AdminSDHolder,CN=System," + domainNC'
        ACECondition='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll)'
        CSCondition='(rule.ActiveDirectoryRights & ActiveDirectoryRights.GenericAll) != 0'
        Rights='GenericAll'; Target='AdminSDHolder'; SearchBase=''; Filter=''
    },
    @{
        ID='ACL-007'; Name='WriteDACL on AdminSDHolder'; Folder='ACL-007_WriteDACL_on_AdminSDHolder'
        Severity='critical'; Pattern='A'; TargetDN='"CN=AdminSDHolder,CN=System,$domainNC"'; TargetDNCS='"CN=AdminSDHolder,CN=System," + domainNC'
        ACECondition='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteDacl)'
        CSCondition='(rule.ActiveDirectoryRights & ActiveDirectoryRights.WriteDacl) != 0'
        Rights='WriteDacl'; Target='AdminSDHolder'; SearchBase=''; Filter=''
    },
    @{
        ID='ACL-008'; Name='WriteOwner on AdminSDHolder'; Folder='ACL-008_WriteOwner_on_AdminSDHolder'
        Severity='critical'; Pattern='A'; TargetDN='"CN=AdminSDHolder,CN=System,$domainNC"'; TargetDNCS='"CN=AdminSDHolder,CN=System," + domainNC'
        ACECondition='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteOwner)'
        CSCondition='(rule.ActiveDirectoryRights & ActiveDirectoryRights.WriteOwner) != 0'
        Rights='WriteOwner'; Target='AdminSDHolder'; SearchBase=''; Filter=''
    },
    @{
        ID='ACL-009'; Name='GenericAll on Domain Admins'; Folder='ACL-009_GenericAll_on_Domain_Admins'
        Severity='critical'; Pattern='A-DA'; TargetDN='$targetDN'; TargetDNCS='targetDN'
        ACECondition='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll)'
        CSCondition='(rule.ActiveDirectoryRights & ActiveDirectoryRights.GenericAll) != 0'
        Rights='GenericAll'; Target='Domain Admins group'; SearchBase=''; Filter=''
    },
    @{
        ID='ACL-010'; Name='WriteDACL on Domain Admins'; Folder='ACL-010_WriteDACL_on_Domain_Admins'
        Severity='critical'; Pattern='A-DA'; TargetDN='$targetDN'; TargetDNCS='targetDN'
        ACECondition='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteDacl)'
        CSCondition='(rule.ActiveDirectoryRights & ActiveDirectoryRights.WriteDacl) != 0'
        Rights='WriteDacl'; Target='Domain Admins group'; SearchBase=''; Filter=''
    },
    @{
        ID='ACL-011'; Name='AddMember Rights on Domain Admins'; Folder='ACL-011_AddMember_Rights_on_Domain_Admins'
        Severity='critical'; Pattern='A-DA'; TargetDN='$targetDN'; TargetDNCS='targetDN'
        ACECondition='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::Self) -and ($_.ObjectType -ne $null) -and ($_.ObjectType.ToString() -eq ''bf9679c0-0de6-11d0-a285-00aa003049e2'')'
        CSCondition='(rule.ActiveDirectoryRights & ActiveDirectoryRights.Self) != 0 && rule.ObjectType == new Guid("bf9679c0-0de6-11d0-a285-00aa003049e2")'
        Rights='Self-Membership (AddMember)'; Target='Domain Admins group'; SearchBase=''; Filter=''
    },
    @{
        ID='ACL-012'; Name='GenericAll on Enterprise Admins'; Folder='ACL-012_GenericAll_on_Enterprise_Admins'
        Severity='critical'; Pattern='A-EA'; TargetDN='$targetDN'; TargetDNCS='targetDN'
        ACECondition='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll)'
        CSCondition='(rule.ActiveDirectoryRights & ActiveDirectoryRights.GenericAll) != 0'
        Rights='GenericAll'; Target='Enterprise Admins group'; SearchBase=''; Filter=''
    },
    @{
        ID='ACL-013'; Name='GenericAll on Domain Controllers OU'; Folder='ACL-013_GenericAll_on_Domain_Controllers_OU'
        Severity='critical'; Pattern='A-OU'; TargetDN='$targetDN'; TargetDNCS='targetDN'
        ACECondition='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll)'
        CSCondition='(rule.ActiveDirectoryRights & ActiveDirectoryRights.GenericAll) != 0'
        Rights='GenericAll'; Target='Domain Controllers OU'; SearchBase=''; Filter=''
    },
    @{
        ID='ACL-014'; Name='WriteDACL on Domain Controllers OU'; Folder='ACL-014_WriteDACL_on_Domain_Controllers_OU'
        Severity='critical'; Pattern='A-OU'; TargetDN='$targetDN'; TargetDNCS='targetDN'
        ACECondition='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteDacl)'
        CSCondition='(rule.ActiveDirectoryRights & ActiveDirectoryRights.WriteDacl) != 0'
        Rights='WriteDacl'; Target='Domain Controllers OU'; SearchBase=''; Filter=''
    },
    # Pattern B checks (ACL-015 through ACL-020) - Scan Multiple Targets
    @{
        ID='ACL-015'; Name='ForceChangePassword on Privileged Users'; Folder='ACL-015_ForceChangePassword_on_Privileged_Users'
        Severity='critical'; Pattern='B'; TargetDN=''; TargetDNCS=''
        ACECondition='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight) -and ($_.ObjectType -ne $null) -and ($_.ObjectType.ToString() -eq ''00299570-246d-11d0-a768-00aa006e0529'')'
        CSCondition='rule.ObjectType == new Guid("00299570-246d-11d0-a768-00aa006e0529")'
        Rights='ForceChangePassword'; Target='Privileged Users'; SearchBase='$domainNC'
        Filter='(&(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(adminCount=1))'
    },
    @{
        ID='ACL-016'; Name='GenericWrite on Privileged Users'; Folder='ACL-016_GenericWrite_on_Privileged_Users'
        Severity='critical'; Pattern='B'; TargetDN=''; TargetDNCS=''
        ACECondition='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericWrite)'
        CSCondition='(rule.ActiveDirectoryRights & ActiveDirectoryRights.GenericWrite) != 0'
        Rights='GenericWrite'; Target='Privileged Users'; SearchBase='$domainNC'
        Filter='(&(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(adminCount=1))'
    },
    @{
        ID='ACL-017'; Name='AllExtendedRights on Privileged Users'; Folder='ACL-017_AllExtendedRights_on_Privileged_Users'
        Severity='high'; Pattern='B'; TargetDN=''; TargetDNCS=''
        ACECondition='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight) -and ($null -eq $_.ObjectType -or $_.ObjectType -eq [guid]::Empty)'
        CSCondition='(rule.ActiveDirectoryRights & ActiveDirectoryRights.ExtendedRight) != 0 && rule.ObjectType == Guid.Empty'
        Rights='AllExtendedRights'; Target='Privileged Users'; SearchBase='$domainNC'
        Filter='(&(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(adminCount=1))'
    },
    @{
        ID='ACL-018'; Name='GenericAll on Domain Controller Computers'; Folder='ACL-018_GenericAll_on_Domain_Controller_Computers'
        Severity='critical'; Pattern='B'; TargetDN=''; TargetDNCS=''
        ACECondition='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll)'
        CSCondition='(rule.ActiveDirectoryRights & ActiveDirectoryRights.GenericAll) != 0'
        Rights='GenericAll'; Target='Domain Controller Computers'; SearchBase='$domainNC'
        Filter='(&(objectCategory=computer)(primaryGroupID=516))'
    },
    @{
        ID='ACL-019'; Name='WriteDACL on Domain Controller Computers'; Folder='ACL-019_WriteDACL_on_Domain_Controller_Computers'
        Severity='critical'; Pattern='B'; TargetDN=''; TargetDNCS=''
        ACECondition='($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteDacl)'
        CSCondition='(rule.ActiveDirectoryRights & ActiveDirectoryRights.WriteDacl) != 0'
        Rights='WriteDacl'; Target='Domain Controller Computers'; SearchBase='$domainNC'
        Filter='(&(objectCategory=computer)(primaryGroupID=516))'
    },
    @{
        ID='ACL-020'; Name='GenericAll or WriteDACL on GPO Objects'; Folder='ACL-020_GenericAll_WriteDACL_on_GPO_Objects'
        Severity='high'; Pattern='B-GPO'; TargetDN=''; TargetDNCS=''
        ACECondition='($_.AccessControlType -eq ''Allow'') -and (($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll) -or ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteDacl))'
        CSCondition='((rule.ActiveDirectoryRights & ActiveDirectoryRights.GenericAll) != 0 || (rule.ActiveDirectoryRights & ActiveDirectoryRights.WriteDacl) != 0)'
        Rights='GenericAll or WriteDacl'; Target='GPO Objects'; SearchBase='"CN=Policies,CN=System,$domainNC"'
        Filter='(objectClass=groupPolicyContainer)'
    }
)

Write-Host "Total checks to process: $($allChecks.Count)" -ForegroundColor Yellow
Write-Host ""

$totalFiles = 0
$startTime = Get-Date

foreach ($check in $allChecks) {
    $checkPath = Join-Path "ACL_Permissions" $check.Folder
    Write-Host "[$($check.ID)] $($check.Name)..." -ForegroundColor Green
    
    # Skip if files already exist
    if ((Test-Path (Join-Path $checkPath "adsi.ps1")) -and
        (Test-Path (Join-Path $checkPath "powershell.ps1")) -and
        (Test-Path (Join-Path $checkPath "cmd.bat")) -and
        (Test-Path (Join-Path $checkPath "csharp.cs")) -and
        (Test-Path (Join-Path $checkPath "combined_multiengine.ps1"))) {
        Write-Host "  All files exist, skipping..." -ForegroundColor Gray
        $totalFiles += 5
        continue
    }
    
    # Generate files based on pattern
    if ($check.Pattern -eq 'A') {
        # Pattern A: Fixed Target (simple)
        & "$PSScriptRoot\generate_pattern_a.ps1" -Check $check
    }
    elseif ($check.Pattern -eq 'A-DA') {
        # Pattern A: Domain Admins (needs LDAP resolution)
        & "$PSScriptRoot\generate_pattern_a_da.ps1" -Check $check
    }
    elseif ($check.Pattern -eq 'A-EA') {
        # Pattern A: Enterprise Admins (needs LDAP resolution)
        & "$PSScriptRoot\generate_pattern_a_ea.ps1" -Check $check
    }
    elseif ($check.Pattern -eq 'A-OU') {
        # Pattern A: Domain Controllers OU (needs LDAP resolution)
        & "$PSScriptRoot\generate_pattern_a_ou.ps1" -Check $check
    }
    elseif ($check.Pattern -eq 'B') {
        # Pattern B: Scan Multiple Targets
        & "$PSScriptRoot\generate_pattern_b.ps1" -Check $check
    }
    elseif ($check.Pattern -eq 'B-GPO') {
        # Pattern B: GPO Objects (special search base)
        & "$PSScriptRoot\generate_pattern_b_gpo.ps1" -Check $check
    }
    
    $totalFiles += 5
    Write-Host "  Created 5 files" -ForegroundColor Gray
}

$elapsed = (Get-Date) - $startTime
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Generation Complete!" -ForegroundColor Green
Write-Host "Total files created: $totalFiles" -ForegroundColor Green
Write-Host "Time elapsed: $($elapsed.TotalSeconds) seconds" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

# Verify file count
Write-Host ""
Write-Host "Verifying file count..." -ForegroundColor Yellow
$ps1Count = (Get-ChildItem "ACL_Permissions" -Recurse -Filter "*.ps1").Count
$csCount  = (Get-ChildItem "ACL_Permissions" -Recurse -Filter "*.cs").Count
$batCount = (Get-ChildItem "ACL_Permissions" -Recurse -Filter "*.bat").Count
$total    = $ps1Count + $csCount + $batCount

Write-Host "PowerShell files (.ps1): $ps1Count (expected: 60)" -ForegroundColor $(if ($ps1Count -eq 60) { 'Green' } else { 'Red' })
Write-Host "C# files (.cs): $csCount (expected: 20)" -ForegroundColor $(if ($csCount -eq 20) { 'Green' } else { 'Red' })
Write-Host "Batch files (.bat): $batCount (expected: 20)" -ForegroundColor $(if ($batCount -eq 20) { 'Green' } else { 'Red' })
Write-Host "Total: $total (expected: 100)" -ForegroundColor $(if ($total -eq 100) { 'Green' } else { 'Red' })
