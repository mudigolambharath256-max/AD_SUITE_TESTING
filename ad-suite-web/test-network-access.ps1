# AD Suite - Network Access Test Script
# Run this to test connectivity between machines

param(
    [Parameter(Mandatory=$true)]
    [string]$DomainMachineIP
)

Write-Host "=== AD Suite Network Connectivity Test ===" -ForegroundColor Green
Write-Host "Testing connection to domain machine: $DomainMachineIP" -ForegroundColor Yellow

# Test basic connectivity
Write-Host "`n1. Testing basic network connectivity..." -ForegroundColor Cyan
$pingResult = Test-Connection -ComputerName $DomainMachineIP -Count 2 -Quiet
if ($pingResult) {
    Write-Host "✓ Ping successful" -ForegroundColor Green
} else {
    Write-Host "✗ Ping failed - Check network connectivity" -ForegroundColor Red
    exit 1
}

# Test port 3001
Write-Host "`n2. Testing backend port (3001)..." -ForegroundColor Cyan
try {
    $tcpTest = Test-NetConnection -ComputerName $DomainMachineIP -Port 3001 -WarningAction SilentlyContinue
    if ($tcpTest.TcpTestSucceeded) {
        Write-Host "✓ Port 3001 is accessible" -ForegroundColor Green
    } else {
        Write-Host "✗ Port 3001 is not accessible" -ForegroundColor Red
        Write-Host "  - Ensure backend is running on domain machine" -ForegroundColor Yellow
        Write-Host "  - Check Windows Firewall settings" -ForegroundColor Yellow
    }
} catch {
    Write-Host "✗ Could not test port 3001: $($_.Exception.Message)" -ForegroundColor Red
}

# Test backend health endpoint
Write-Host "`n3. Testing backend API..." -ForegroundColor Cyan
try {
    $healthUrl = "http://$DomainMachineIP:3001/api/health"
    $response = Invoke-RestMethod -Uri $healthUrl -TimeoutSec 10
    if ($response.status -eq "healthy") {
        Write-Host "✓ Backend API is responding" -ForegroundColor Green
        Write-Host "  Suite Root: $($response.suiteRoot)" -ForegroundColor Gray
        Write-Host "  DB Size: $($response.dbSize)" -ForegroundColor Gray
    } else {
        Write-Host "✗ Backend API returned unexpected status: $($response.status)" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Backend API not accessible: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  - Ensure backend server is running" -ForegroundColor Yellow
    Write-Host "  - Check the URL: http://$DomainMachineIP:3001" -ForegroundColor Yellow
}

# Test AD connectivity from domain machine
Write-Host "`n4. Testing Active Directory access..." -ForegroundColor Cyan
try {
    $validateUrl = "http://$DomainMachineIP:3001/api/scan/validate-target"
    $body = @{} | ConvertTo-Json
    $response = Invoke-RestMethod -Uri $validateUrl -Method POST -Body $body -ContentType "application/json" -TimeoutSec 15
    
    if ($response.valid) {
        Write-Host "✓ Active Directory access confirmed" -ForegroundColor Green
        Write-Host "  Domain NC: $($response.domainNC)" -ForegroundColor Gray
    } else {
        Write-Host "✗ Active Directory access failed: $($response.error)" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Could not test AD access: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Green
Write-Host "If all tests pass, update your frontend .env file:" -ForegroundColor Yellow
Write-Host "VITE_BACKEND_URL=http://$DomainMachineIP:3001" -ForegroundColor Cyan