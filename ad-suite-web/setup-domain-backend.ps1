# AD Suite - Domain Backend Setup Script
# Run this script on your domain-joined machine

Write-Host "=== AD Suite Domain Backend Setup ===" -ForegroundColor Green

# Check if running on domain-joined machine
$isDomainJoined = (Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain
if (-not $isDomainJoined) {
    Write-Warning "This machine is not domain-joined. The backend should run on a domain-joined machine for AD access."
    $continue = Read-Host "Continue anyway? (y/N)"
    if ($continue -ne 'y' -and $continue -ne 'Y') {
        exit 1
    }
}

# Get current machine IP
$networkAdapters = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne "127.0.0.1" -and $_.PrefixOrigin -eq "Dhcp" }
$machineIP = $networkAdapters[0].IPAddress

Write-Host "Domain-joined machine IP: $machineIP" -ForegroundColor Yellow

# Check if Node.js is installed
try {
    $nodeVersion = node --version
    Write-Host "Node.js version: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Error "Node.js is not installed. Please install Node.js from https://nodejs.org/"
    exit 1
}

# Navigate to backend directory
$backendPath = Join-Path $PSScriptRoot "backend"
if (-not (Test-Path $backendPath)) {
    Write-Error "Backend directory not found at: $backendPath"
    exit 1
}

Set-Location $backendPath

# Install dependencies
Write-Host "Installing backend dependencies..." -ForegroundColor Yellow
npm install

# Configure firewall
Write-Host "Configuring Windows Firewall..." -ForegroundColor Yellow
try {
    New-NetFirewallRule -DisplayName "AD Suite Backend" -Direction Inbound -LocalPort 3001 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue
    Write-Host "Firewall rule created for port 3001" -ForegroundColor Green
} catch {
    Write-Warning "Could not create firewall rule. You may need to run as Administrator."
}

# Create start script
$startScript = @"
@echo off
echo Starting AD Suite Backend on Domain Machine...
echo Backend will be available at: http://$machineIP:3001
echo.
cd /d "$backendPath"
npm start
pause
"@

$startScript | Out-File -FilePath "start-backend.bat" -Encoding ASCII

Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Green
Write-Host "1. Backend configured to run on this domain-joined machine"
Write-Host "2. Firewall rule created for port 3001"
Write-Host "3. Start script created: start-backend.bat"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Run 'start-backend.bat' to start the backend server"
Write-Host "2. Update your frontend .env file with: VITE_BACKEND_URL=http://$machineIP:3001"
Write-Host "3. Restart your frontend server"
Write-Host ""
Write-Host "Backend will be accessible at: http://$machineIP:3001" -ForegroundColor Cyan