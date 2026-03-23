# Get Host Machine IP Address
Write-Host "=== Host Machine Network Information ===" -ForegroundColor Green

# Get all network adapters with IPv4 addresses
$adapters = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
    $_.IPAddress -ne "127.0.0.1" -and 
    $_.PrefixOrigin -eq "Dhcp" -and
    $_.AddressState -eq "Preferred"
}

Write-Host "`nAvailable IP Addresses:" -ForegroundColor Yellow
foreach ($adapter in $adapters) {
    $interface = Get-NetAdapter -InterfaceIndex $adapter.InterfaceIndex
    Write-Host "  $($adapter.IPAddress) - $($interface.Name)" -ForegroundColor Cyan
}

# Get the primary IP (usually the first DHCP assigned one)
$primaryIP = $adapters[0].IPAddress
Write-Host "`nPrimary IP Address: $primaryIP" -ForegroundColor Green

Write-Host "`nTo fix network access to Run Scans page:" -ForegroundColor Yellow
Write-Host "1. Update frontend/.env file:" -ForegroundColor White
Write-Host "   VITE_BACKEND_URL=http://$primaryIP:3001" -ForegroundColor Cyan
Write-Host "`n2. Restart your frontend server:" -ForegroundColor White
Write-Host "   npm run dev" -ForegroundColor Cyan
Write-Host "`n3. Access website from network machines using:" -ForegroundColor White
Write-Host "   http://$primaryIP:5173" -ForegroundColor Cyan

# Test if backend is running
Write-Host "`nTesting backend connectivity..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "http://localhost:3001/api/health" -TimeoutSec 5
    Write-Host "✓ Backend is running on localhost:3001" -ForegroundColor Green
    Write-Host "  Status: $($response.status)" -ForegroundColor Gray
} catch {
    Write-Host "✗ Backend is not running on localhost:3001" -ForegroundColor Red
    Write-Host "  Start backend with: cd backend && npm start" -ForegroundColor Yellow
}

# Check firewall
Write-Host "`nChecking Windows Firewall..." -ForegroundColor Yellow
$frontendRule = Get-NetFirewallRule -DisplayName "AD Suite Frontend" -ErrorAction SilentlyContinue
$backendRule = Get-NetFirewallRule -DisplayName "AD Suite Backend" -ErrorAction SilentlyContinue

if ($frontendRule) {
    Write-Host "✓ Frontend firewall rule exists" -ForegroundColor Green
} else {
    Write-Host "✗ Frontend firewall rule missing" -ForegroundColor Red
    Write-Host "  Run: New-NetFirewallRule -DisplayName 'AD Suite Frontend' -Direction Inbound -LocalPort 5173 -Protocol TCP -Action Allow" -ForegroundColor Yellow
}

if ($backendRule) {
    Write-Host "✓ Backend firewall rule exists" -ForegroundColor Green
} else {
    Write-Host "✗ Backend firewall rule missing" -ForegroundColor Red
    Write-Host "  Run: New-NetFirewallRule -DisplayName 'AD Suite Backend' -Direction Inbound -LocalPort 3001 -Protocol TCP -Action Allow" -ForegroundColor Yellow
}