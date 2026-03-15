# Phase 3: Fix BloodHound Export Block String Terminators (Patterns D, E)
# Fixes BH export block string errors for Pattern D/E files

param(
    [string]$SuiteRoot = ".",
    [string]$OutputFile = "phase3-fix-results.json"
)

# Initialize results tracking
$results = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    SuiteRoot = (Resolve-Path $SuiteRoot).Path
    TotalScanned = 0
    TotalFixed = 0
    FixedFiles = @()
    FailedToFix = @()
    ByPattern = @{
        PatternD = @{ Count = 0; Files = @() }
        PatternE = @{ Count = 0; Files = @() }
    }
}

function Test-PowerShellSyntax {
    param([string]$FilePath)
    
    try {
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($FilePath, [ref]$null, [ref]$errors)
        
        return @{
            HasErrors = $errors.Count -gt 0
            ErrorCount = $errors.Count
            Errors = $errors | ForEach-Object {
                @{
                    Line = $_.Extent.StartLineNumber
                    Column = $_.Extent.StartColumnNumber
                    Message = $_.Message
                    ErrorId = $_.ErrorId
                }
            }
        }
    }
    catch {
        return @{
            HasErrors = $true
            ErrorCount = 1
            Errors = @(@{
                Line = 0
                Column = 0
                Message = "Failed to parse file: $($_.Exception.Message)"
                ErrorId = "ParseException"
            })
        }
    }
}

function Get-PatternType {
    param(
        [array]$Errors,
        [string]$FilePath,
        [string]$Content
    )
    
    # Pattern D: Two PropertiesToLoad errors + BH export string error
    $hasPropertiesToLoadErrors = $Errors | Where-Object { 
        $_.Message -like "*Missing closing*)*" -and $_.Line -in @(20, 134) 
    }
    $hasUnexpectedTokenErrors = $Errors | Where-Object { 
        $_.Message -like "*Unexpected token*" -and $_.Line -in @(22, 136) 
    }
    $hasStringTerminatorError = $Errors | Where-Object { 
        $_.Message -like "*string is missing the terminator*" -and $_.Line -ge 173 
    }
    
    if ($hasPropertiesToLoadErrors.Count -ge 2 -and $hasUnexpectedTokenErrors.Count -ge 2 -and $hasStringTerminatorError) {
        return 'D'
    }
    
    # Pattern E: Only BH export string error
    $hasBHExportError = $Errors | Where-Object { 
        $_.Message -like "*Unexpected token*AD*" -and $_.Line -ge 161 
    }
    
    if ($hasBHExportError -and -not $hasPropertiesToLoadErrors) {
        return 'E'
    }
    
    # Check for malformed PSCustomObject (common issue)
    if ($Content -match 'Name = if.*\{\s*\$props.*\[0\]\s*$' -or 
        $Content -match 'UserAccountControl = if.*\{\s*\$props.*\[0\]\s*$' -or
        $Content -match '\} else \{ ''N/A'' \} \} else \{ ''N/A''') {
        return 'D'  # Treat malformed PSCustomObject as Pattern D
    }
    
    # Check for BloodHound export block issues
    if ($Content -match '# .*BloodHound.*Export.*Block' -and 
        ($Content -match 'checkid.*=.*''[^'']*$' -or 
         $Content -match 'severity.*=.*''[^'']*$' -or
         $Content -match 'name.*=.*"[^"]*Active Directory[^"]*$')) {
        return 'E'
    }
    
    return $null
}

function Fix-PSCustomObjectProperties {
    param([string]$Content)
    
    # Fix malformed PSCustomObject properties
    $Content = $Content -replace 'Name = if \(\$props\[''name''\]\.Count -gt 0\) \{ \$props\[''name''\]\[0\]\s*$', 'Name = if ($props[''name''].Count -gt 0) { $props[''name''][0] } else { ''N/A'' }'
    $Content = $Content -replace 'UserAccountControl = if \(\$props\[''useraccountcontrol''\]\.Count -gt 0\) \{ \$props\[''useraccountcontrol''\]\[0\]\s*$', 'UserAccountControl = if ($props[''useraccountcontrol''].Count -gt 0) { $props[''useraccountcontrol''][0] } else { ''N/A'' }'
    $Content = $Content -replace 'SamAccountName = if \(\$props\[''samaccountname''\]\.Count -gt 0\) \{ \$props\[''samaccountname''\]\[0\]\s*$', 'SamAccountName = if ($props[''samaccountname''].Count -gt 0) { $props[''samaccountname''][0] } else { ''N/A'' }'
    
    # Remove duplicate or malformed property lines
    $Content = $Content -replace '\s*UserAccountControl = if \(\$props\[''useraccountcontrol''\] -and \$props\[''useraccountcontrol''\]\.Count -gt 0\) \{ \$props\[''useraccountcontrol''\]\[0\] \} else \{ ''N/A'' \}\s*', ''
    $Content = $Content -replace '\s*SamAccountName = if \(\$props\[''samaccountname''\] -and \$props\[''samaccountname''\]\.Count -gt 0\) \{ \$props\[''samaccountname''\]\[0\] \} else \{ ''N/A'' \} \} else \{ ''N/A'' \} \} else \{ ''N/A''\s*', ''
    $Content = $Content -replace '\s*SamAccountName = if \(\$props\[''samaccountname''\]\.Count -gt 0\) \{ \$props\[''samaccountname''\]\[0\] \} else \{ ''N/A'' \} \}\s*', ''
    $Content = $Content -replace '\s*SamAccountName = if \(\$props\[''samaccountname''\]\.Count -gt 0\) \{ \$props\[''samaccountname''\]\[0\] \} else \{ ''N/A'' \} \} else \{ ''N/A'' \}\s*', ''
    
    return $Content
}

function Fix-BloodHoundExportBlock {
    param(
        [string]$Content,
        [string]$CheckID,
        [string]$CheckName,
        [string]$Severity = 'HIGH',
        [string]$Category = 'Authentication'
    )
    
    # Clean BloodHound export block template
    $bhTemplate = @"

# ============================================================================
# BLOODHOUND EXPORT BLOCK
# ============================================================================
# Automatically export results to BloodHound-compatible JSON format
# ============================================================================

try {
    # Initialize session
    if (-not `$env:ADSUITE_SESSION_ID) {
        `$env:ADSUITE_SESSION_ID = Get-Date -Format 'yyyyMMdd_HHmmss'
        Write-Host "[BloodHound] New session: `$env:ADSUITE_SESSION_ID" -ForegroundColor Cyan
    }
    
    `$bhDir = "C:\ADSuite_BloodHound\SESSION_`$env:ADSUITE_SESSION_ID"
    if (-not (Test-Path `$bhDir)) {
        New-Item -ItemType Directory -Path `$bhDir -Force | Out-Null
    }
    
    # Convert results to BloodHound format
    if (`$results -and `$results.Count -gt 0) {
        `$bhNodes = @()
        
        foreach (`$item in `$results) {
            # Extract SID as ObjectIdentifier
            `$objectId = if (`$item.objectSid) {
                try {
                    (New-Object System.Security.Principal.SecurityIdentifier(`$item.objectSid, 0)).Value
                } catch {
                    `$item.DistinguishedName
                }
            } else {
                `$item.DistinguishedName
            }
            
            # Determine object type
            `$objectType = if (`$item.objectClass -contains 'user') { 'User' }
                         elseif (`$item.objectClass -contains 'computer') { 'Computer' }
                         elseif (`$item.objectClass -contains 'group') { 'Group' }
                         else { 'Base' }
            
            # Extract domain from DN
            `$domain = if (`$item.DistinguishedName -match 'DC=([^,]+)') {
                (`$matches[1..(`$matches.Count-1)] -join '.').ToUpper()
            } else { 'UNKNOWN' }
            
            `$bhNodes += @{
                ObjectIdentifier = `$objectId
                ObjectType = `$objectType
                Properties = @{
                    name = `$item.Name
                    distinguishedname = `$item.DistinguishedName
                    samaccountname = `$item.samAccountName
                    domain = `$domain
                    checkid = '$CheckID'
                    severity = '$Severity'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        `$bhOutput = @{ nodes = `$bhNodes } | ConvertTo-Json -Depth 10
        `$bhFile = Join-Path `$bhDir "${CheckID}_nodes.json"
        Set-Content -Path `$bhFile -Value `$bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported `$(`$bhNodes.Count) nodes to: `$bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: `$_"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================
"@

    # Remove existing BloodHound export block
    $Content = $Content -replace '(?s)# .*BloodHound.*Export.*Block.*?# .*END.*BLOODHOUND.*EXPORT.*BLOCK.*?# .*', ''
    
    # Add clean template at the end
    $Content = $Content.TrimEnd() + "`n" + $bhTemplate + "`n"
    
    return $Content
}

function Fix-PropertiesToLoadArrays {
    param([string]$Content)
    
    # Fix PropertiesToLoad arrays that span multiple lines
    $Content = $Content -replace '(?s)\(\@\([^)]+\)\s*\|\s*ForEach-Object[^}]+\}\)', '(@(''name'', ''distinguishedName'', ''whenCreated'', ''whenChanged'', ''userAccountControl'', ''samAccountName'', ''objectSid'') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) })'
    
    return $Content
}

Write-Host "=== BloodHound Export Block String Terminator Fix (Patterns D, E) ===" -ForegroundColor Yellow
Write-Host "Scanning for Pattern D and E files..." -ForegroundColor White
Write-Host ""

# Find all adsi.ps1 files
$adsiFiles = Get-ChildItem -Path $SuiteRoot -Recurse -Filter "adsi.ps1" | Sort-Object FullName

foreach ($file in $adsiFiles) {
    $results.TotalScanned++
    $relativePath = $file.FullName -replace [regex]::Escape((Get-Item $SuiteRoot).FullName), ''
    $relativePath = $relativePath.TrimStart('\')
    
    Write-Host "Checking: $relativePath" -ForegroundColor Gray
    
    # Read file content
    $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
    
    # Parse the file for errors
    $parseResult = Test-PowerShellSyntax -FilePath $file.FullName
    
    # Determine if this is Pattern D or E
    $pattern = Get-PatternType -Errors $parseResult.Errors -FilePath $file.FullName -Content $content
    
    if ($pattern -in @('D', 'E')) {
        Write-Host "  → Pattern $pattern detected" -ForegroundColor Yellow
        
        # Extract check information from file path
        $checkMatch = $relativePath -match '([A-Z]+-\d+)_'
        $checkID = if ($checkMatch) { $matches[1] } else { 'UNKNOWN' }
        
        $checkNameMatch = $relativePath -match '_([^\\]+)\\adsi\.ps1$'
        $checkName = if ($checkNameMatch) { $matches[1] -replace '_', ' ' } else { 'Unknown Check' }
        
        $categoryMatch = $relativePath -match '^([^\\]+)\\'
        $category = if ($categoryMatch) { $matches[1] } else { 'Unknown' }
        
        try {
            # Apply fixes based on pattern
            $fixedContent = $content
            
            if ($pattern -eq 'D') {
                # Pattern D: Fix PropertiesToLoad + BH export
                $fixedContent = Fix-PropertiesToLoadArrays -Content $fixedContent
                $fixedContent = Fix-PSCustomObjectProperties -Content $fixedContent
                $fixedContent = Fix-BloodHoundExportBlock -Content $fixedContent -CheckID $checkID -CheckName $checkName -Category $category
            }
            elseif ($pattern -eq 'E') {
                # Pattern E: Fix BH export only
                $fixedContent = Fix-PSCustomObjectProperties -Content $fixedContent
                $fixedContent = Fix-BloodHoundExportBlock -Content $fixedContent -CheckID $checkID -CheckName $checkName -Category $category
            }
            
            # Write fixed content back to file
            Set-Content -Path $file.FullName -Value $fixedContent -Encoding UTF8
            
            # Verify the fix worked
            $verifyResult = Test-PowerShellSyntax -FilePath $file.FullName
            
            if ($verifyResult.HasErrors) {
                Write-Host "  → Fix failed - still has $($verifyResult.ErrorCount) errors" -ForegroundColor Red
                $results.FailedToFix += @{
                    File = $relativePath
                    Pattern = $pattern
                    ErrorCount = $verifyResult.ErrorCount
                    FirstError = if ($verifyResult.Errors) { $verifyResult.Errors[0].Message } else { "Unknown" }
                }
            } else {
                Write-Host "  → Fixed successfully" -ForegroundColor Green
                $results.TotalFixed++
                $results.ByPattern["Pattern$pattern"].Count++
                $results.ByPattern["Pattern$pattern"].Files += $relativePath
                $results.FixedFiles += @{
                    File = $relativePath
                    Pattern = $pattern
                    CheckID = $checkID
                    CheckName = $checkName
                }
            }
            
        } catch {
            Write-Host "  → Fix failed with exception: $_" -ForegroundColor Red
            $results.FailedToFix += @{
                File = $relativePath
                Pattern = $pattern
                ErrorCount = -1
                FirstError = $_.Exception.Message
            }
        }
    } else {
        Write-Host "  → Not Pattern D or E" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "=== FIX COMPLETE ===" -ForegroundColor Yellow
Write-Host "Total files scanned: $($results.TotalScanned)" -ForegroundColor White
Write-Host "Total files fixed: $($results.TotalFixed)" -ForegroundColor Green
Write-Host "Pattern D fixed: $($results.ByPattern.PatternD.Count)" -ForegroundColor Cyan
Write-Host "Pattern E fixed: $($results.ByPattern.PatternE.Count)" -ForegroundColor Cyan
Write-Host "Failed to fix: $($results.FailedToFix.Count)" -ForegroundColor Red

if ($results.FailedToFix.Count -gt 0) {
    Write-Host ""
    Write-Host "Failed files:" -ForegroundColor Red
    $results.FailedToFix | ForEach-Object {
        Write-Host "  $($_.File): $($_.FirstError)" -ForegroundColor DarkRed
    }
}

# Save results to JSON
$outputPath = Join-Path $SuiteRoot $OutputFile
$results | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputPath -Encoding UTF8

Write-Host ""
Write-Host "Results saved to: $outputPath" -ForegroundColor Green
Write-Host "BloodHound export block string terminator fix complete!" -ForegroundColor Green