#requires -Version 5.1
param([Parameter(Mandatory)][string]$JsonPath)
$j = Get-Content -LiteralPath $JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
$ids = @($j.checks | ForEach-Object { [string]$_.id })
$g = $ids | Group-Object | Where-Object { $_.Count -gt 1 }
foreach ($x in $g) { Write-Output "$($x.Name) x$($x.Count)" }
