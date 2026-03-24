# Batch generator for ACL-004 through ACL-020
# This script creates all remaining 85 files

# Define check specifications
$checks = @(
    @{ID='ACL-004'; Name='AllExtendedRights on Domain Object'; Severity='critical'; Pattern='A'; TargetDN='$domainNC'; ACECondition='($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight) -and ($null -eq $_.ObjectType -or $_.ObjectType -eq [guid]::Empty)'; Rights='AllExtendedRights'; CSCondition='(rule.ActiveDirectoryRights & ActiveDirectoryRights.ExtendedRight) != 0 && rule.ObjectType == Guid.Empty'; Target='Domain NC object'}
    @{ID='ACL-005'; Name='DCSync Rights DS-Replication-Get-Changes-All'; Severity='critical'; Pattern='A'; TargetDN='$domainNC'; ACECondition='($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight) -and ($_.ObjectType -ne $null) -and ($_.ObjectType.ToString() -eq ''1131f6ad-9c07-11d1-f79f-00c04fc2dcd2'')'; Rights='DS-Replication-Get-Changes-All (DCSync)'; CSCondition='rule.ObjectType == new Guid("1131f6ad-9c07-11d1-f79f-00c04fc2dcd2")'; Target='Domain NC object'}
)

Write-Host "Batch generator ready. Run sections below to create files."
Write-Host "Total checks to process: $($checks.Count)"
