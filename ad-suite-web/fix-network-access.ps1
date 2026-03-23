# Quick Fix for Network Access to Run Scans Page
Write-Host "=== Fixing Network Access to Run Scans Page ===" -ForegroundColor Green

# Get host machine IP
$adapters = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
    $_.IPAddress -ne "127.0.0.1" -and 
    $_.PrefixOrigin -eq "Dhcp" -and
    $_.AddressState -eq "Preferred"
}

if ($adapters.Count -eq 0) {
    Write-Error "No network adapters found with DHCP IP addresses"
    exit 1
}

$hostIP = $adapters[0].IPAddress
Write-Host "Host machine IP: $hostIP" -ForegroundColor Yellow

# Update frontend .env file
$envPath = "frontend\.env"
if (Test-Path $envPath) {
    Write-Host "Updating frontend/.env file..." -ForegroundColor Yellow
    
    $envContent = Get-Content $envPath
    $newContent = $envContent -replace "VITE_BACKEND_URL=.*", "VITE_BACKEND_URL=http://$hostIP:3001"
    $newContent | Set-Content $envPath
    
    Write-Host "✓ Updated VITE_BACKEND_URL=http://$hostIP:3001" -ForegroundColor Green
} else {
    Write-Error "Frontend .env file not found at: $envPath"
    exit 1
}

# Create firewall rules
Write-Host "Creating firewall rules..." -ForegroundColor Yellow

try {
    New-NetFirewallRule -DisplayName "AD Suite Frontend" -Direction Inbound -LocalPort 5173 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue
    Write-Host "✓ Frontend firewall rule created (port 5173)" -ForegroundColor Green
} catch {
    Write-Host "! Frontend firewall rule already exists or failed to create" -ForegroundColor Yellow
}

try {
    New-NetFirewallRule -DisplayName "AD Suite Backend" -Direction Inbound -LocalPort 3001 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue
    Write-Host "✓ Backend firewall rule created (port 3001)" -ForegroundColor Green
} catch {
    Write-Host "! Backend firewall rule already exists or failed to create" -ForegroundColor Yellow
}

# Test backend
Write-Host "Testing backend..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "http://localhost:3001/api/health" -TimeoutSec 5
    Write-Host "✓ Backend is running and responding" -ForegroundColor Green
} catch {
    Write-Host "✗ Backend is not running" -ForegroundColor Red
    Write-Host "  Please start the backend first:" -ForegroundColor Yellow
    Write-Host "  cd backend" -ForegroundColor Cyan
    Write-Host "  npm start" -ForegroundColor Cyan
    Write-Host ""
}

Write-Host ""
Write-Host "=== Next Steps ===" -ForegroundColor Green
Write-Host "1. Restart your frontend server:" -ForegroundColor White
Write-Host "   cd frontend" -ForegroundColor Cyan
Write-Host "   npm run dev" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. Access from any network machine:" -ForegroundColor White
Write-Host "   http://$hostIP:5173" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. The Run Scans page should now work from all network machines!" -ForegroundColor Green