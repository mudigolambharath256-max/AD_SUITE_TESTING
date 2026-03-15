# Fix Corrupted ADSI Files
# Repairs PSCustomObject blocks with syntax errors

param(
    [Parameter(Mandatory=$false)]
    [string]$SuiteRoot = "C:\Users\acer\Downloads\AD_suiteXXX"
)

$ErrorActionPreference = 'Continue'
$fixed = 0
$failed = 0
$skipped = 0

Write-Host "=== Fixing Corrupted ADSI Files ===" -ForegroundColor Cyan
Write-Host ""

# Find all adsi.ps1 files
$adsiFiles = Get-ChildItem -Path $SuiteRoot -Recurse -Filter "adsi.ps1" -File

Write-Host "Found $($adsiFiles.Count) ADSI files to check"
Write-Host ""

foreach ($file in $adsiFiles) {
    try {
        $content = Get-Content $file.FullName -Raw -ErrorAction Stop
        
        # Test if file parses correctly
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$errors)
        
        if ($errors.Count -eq 0) {
            $script:skipped++
            continue
        }
        
        # Check if it has the corrupted pattern
        if ($content -notmatch '\[PSCustomObject\]@\{') {
            $script:skipped++
            continue
        }
        
        Write-Host "Fixing: $($file.Directory.Name)" -ForegroundColor Yellow
        
        # Extract the header section (everything before the LDAP search)
        $headerMatch = [regex]::Match($content, '^(.*?)(?=# LDAP search|$searcher = \[ADSISearcher\])', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        $header = if ($headerMatch.Success) { $headerMatch.Groups[1].Value.TrimEnd() } else { "" }
        
        # Extract the LDAP filter
        $filterMatch = [regex]::Match($content, '\$searcher = \[ADSISearcher\]''([^'']+)''')
        if (-not $filterMatch.Success) {
            Write-Host "  SKIP: No LDAP filter found" -ForegroundColor Red
            $script:failed++
            continue
        }
        $filter = $filterMatch.Groups[1].Value
        
        # Extract properties to load
        $propsMatch = [regex]::Match($content, '@\(([^)]+)\)\s*\|\s*ForEach-Object\s*\{\s*\[void\]\$searcher\.PropertiesToLoad\.Add')
        $properties = if ($propsMatch.Success) {
            $propsMatch.Groups[1].Value -replace '\s+', ' ' -replace "'", ""
        } else {
            "'name', 'distinguishedName', 'samAccountName'"
        }
        
        # Extract the Label from PSCustomObject
        $labelMatch = [regex]::Match($content, 'Label\s*=\s*''([^'']+)''')
        $label = if ($labelMatch.Success) { $labelMatch.Groups[1].Value } else { $file.Directory.Name }
        
        # Build clean ADSI script
        $newContent = @"
$header

# LDAP search (ADSI / DirectorySearcher)
`$searcher = [ADSISearcher]'$filter'
`$searcher.PageSize = 1000
`$searcher.PropertiesToLoad.Clear()
@($properties) | ForEach-Object { [void]`$searcher.PropertiesToLoad.Add(`$_) }
`$results = `$searcher.FindAll()
`$results | ForEach-Object {
  `$p = `$_.Properties
  [PSCustomObject]@{
    Label = '$label'
    Name = `$p['name'][0]
    DistinguishedName = `$p['distinguishedname'][0]
  }
}
"@
        
        # Validate the new content
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseInput($newContent, [ref]$null, [ref]$errors)
        
        if ($errors.Count -eq 0) {
            Set-Content -Path $file.FullName -Value $newContent -Encoding UTF8 -Force
            Write-Host "  OK: $($file.Directory.Name)" -ForegroundColor Green
            $script:fixed++
        } else {
            Write-Host "  FAIL: Validation failed" -ForegroundColor Red
            $script:failed++
        }
    }
    catch {
        Write-Host "  ERROR: $($file.Directory.Name) - $($_.Exception.Message)" -ForegroundColor Red
        $script:failed++
    }
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Fixed: $fixed" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor Red
Write-Host "Skipped (already valid): $skipped" -ForegroundColor Yellow
