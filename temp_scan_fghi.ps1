# Pattern F, G, H, I Scanner
$patterns = @{
    'F' = @{ Name = 'Pattern F'; Description = 'TMGMT line 46 Unexpected token }' }
    'G' = @{ Name = 'Pattern G'; Description = 'TRST catch block ordering + BH export' }
    'H' = @{ Name = 'Pattern H'; Description = 'DC unclosed strings with backtick-n' }
    'I' = @{ Name = 'Pattern I'; Description = 'GPO regex hashtable quoting' }
}

$results = @{
    F = @()
    G = @()
    H = @()
    I = @()
}

# Scan TMGMT files for Pattern F
Get-ChildItem "Trust_Management" -Recurse -Filter "adsi.ps1" | ForEach-Object {
    if (Test-Path $_.FullName) {
        $content = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
        if ($content) {
            $errors = $null
            try {
                [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$errors)
                if ($errors -and ($errors | Where-Object { $_.Message -like "*Unexpected token '}'*" -and $_.Extent.StartLineNumber -eq 46 })) {
                    $results.F += $_.FullName
                }
            } catch {}
        }
    }
}

# Scan TRST files for Pattern G
Get-ChildItem "Trust_Relationships" -Recurse -Filter "adsi.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
    if (Test-Path $_.FullName) {
        $content = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
        if ($content) {
            $errors = $null
            try {
                [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$errors)
                if ($errors -and ($errors | Where-Object { $_.Message -like "*Catch block must be the last*" })) {
                    $results.G += $_.FullName
                }
            } catch {}
        }
    }
}

# Scan DC files for Pattern H
Get-ChildItem "Domain_Controllers" -Recurse -Filter "adsi.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
    if (Test-Path $_.FullName) {
        $content = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
        if ($content) {
            $errors = $null
            try {
                [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$errors)
                if ($errors -and ($errors | Where-Object { $_.Message -like "*Unexpected token*nSummary*" })) {
                    $results.H += $_.FullName
                }
            } catch {}
        }
    }
}

# Scan GPO-051 for Pattern I
$gpoFile = "Group_Policy\GPO-051_SYSVOL_Credential_Content_Scan\adsi.ps1"
if (Test-Path $gpoFile) {
    $content = Get-Content $gpoFile -Raw -ErrorAction SilentlyContinue
    if ($content) {
        $errors = $null
        try {
            [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$errors)
            if ($errors) {
                $results.I += (Resolve-Path $gpoFile).Path
            }
        } catch {}
    }
}

# Output results
Write-Host "=== Pattern F, G, H, I Scan Results ===" -ForegroundColor Cyan
foreach ($pattern in @('F', 'G', 'H', 'I')) {
    Write-Host "`nPattern $pattern ($($patterns[$pattern].Description)):" -ForegroundColor Yellow
    if ($results[$pattern].Count -gt 0) {
        $results[$pattern] | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
    } else {
        Write-Host "  No files found" -ForegroundColor Gray
    }
}
