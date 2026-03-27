# Pull Latest Fixes Script
# Run this to get the latest bug fixes

Write-Host "Pulling latest fixes from GitHub..." -ForegroundColor Cyan

try {
    # Pull latest changes
    git pull origin mod
    
    Write-Host "`n✅ Fixes pulled successfully!" -ForegroundColor Green
    Write-Host "`nYou can now run the scan without errors:" -ForegroundColor Yellow
    Write-Host "  .\Invoke-ADSuiteScan.ps1 -ChecksJsonPath .\checks.json -OutputDirectory .\out\test" -ForegroundColor White
    
} catch {
    Write-Host "`n❌ Error pulling fixes: $_" -ForegroundColor Red
    Write-Host "`nTry re-cloning the repository:" -ForegroundColor Yellow
    Write-Host "  cd .." -ForegroundColor White
    Write-Host "  Remove-Item -Recurse -Force AD_SUITE_TESTING" -ForegroundColor White
    Write-Host "  git clone -b mod https://github.com/mudigolambharath256-max/AD_SUITE_TESTING.git" -ForegroundColor White
    Write-Host "  cd AD_SUITE_TESTING" -ForegroundColor White
}
