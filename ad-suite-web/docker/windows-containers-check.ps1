# Run this before attempting to build the Docker image.
# It checks that Docker is installed, running, and in Windows containers mode.

#Requires -RunAsAdministrator

Write-Host "`n=== AD Security Suite — Docker Pre-Flight Check ===" -ForegroundColor Cyan

$pass = $true

# ── Check 1: Docker is installed ─────────────────────────────────────────
Write-Host "`n[1/5] Docker installation..." -ForegroundColor Yellow
$docker = Get-Command docker -ErrorAction SilentlyContinue
if ($docker) {
    $ver = docker --version 2>&1
    Write-Host "  PASS: $ver" -ForegroundColor Green
} else {
    Write-Host "  FAIL: Docker not found. Install Docker Desktop from https://www.docker.com/products/docker-desktop" -ForegroundColor Red
    $pass = $false
}

# ── Check 2: Docker daemon is running ─────────────────────────────────────
Write-Host "`n[2/5] Docker daemon status..." -ForegroundColor Yellow
try {
    docker info 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  PASS: Docker daemon is running" -ForegroundColor Green
    } else {
        Write-Host "  FAIL: Docker daemon not responding. Start Docker Desktop and try again." -ForegroundColor Red
        $pass = $false
    }
} catch {
    Write-Host "  FAIL: Cannot reach Docker daemon. $_" -ForegroundColor Red
    $pass = $false
}

# ── Check 3: Windows containers mode ──────────────────────────────────────
Write-Host "`n[3/5] Windows containers mode..." -ForegroundColor Yellow
try {
    $info = docker info --format '{{.OSType}}' 2>&1
    if ($info -eq 'windows') {
        Write-Host "  PASS: Docker is in Windows containers mode" -ForegroundColor Green
    } else {
        Write-Host "  FAIL: Docker is in '$info' mode. Right-click Docker Desktop tray icon" -ForegroundColor Red
        Write-Host "        and select 'Switch to Windows containers...'" -ForegroundColor Red
        $pass = $false
    }
} catch {
    Write-Host "  SKIP: Could not determine container mode" -ForegroundColor Yellow
}

# ── Check 4: Domain membership ────────────────────────────────────────────
Write-Host "`n[4/5] Domain membership..." -ForegroundColor Yellow
$cs = Get-WmiObject -Class Win32_ComputerSystem
if ($cs.PartOfDomain) {
    Write-Host "  PASS: Machine is joined to domain: $($cs.Domain)" -ForegroundColor Green
} else {
    Write-Host "  WARN: Machine is NOT domain-joined. AD scripts will return empty results." -ForegroundColor Yellow
    Write-Host "        For full functionality, run on a domain-joined Windows machine." -ForegroundColor Yellow
}

# ── Check 5: docker-compose ───────────────────────────────────────────────
Write-Host "`n[5/5] docker-compose availability..." -ForegroundColor Yellow
$dcv = docker compose version 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  PASS: $dcv" -ForegroundColor Green
} else {
    $dco = Get-Command docker-compose -ErrorAction SilentlyContinue
    if ($dco) {
        Write-Host "  PASS: docker-compose (standalone) found" -ForegroundColor Green
    } else {
        Write-Host "  FAIL: docker-compose not found. Included with Docker Desktop." -ForegroundColor Red
        $pass = $false
    }
}

# ── Summary ────────────────────────────────────────────────────────────────
Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
if ($pass) {
    Write-Host "✓ All checks passed. Ready to build:" -ForegroundColor Green
    Write-Host "  docker compose -f docker/docker-compose.yml up --build -d" -ForegroundColor White
    Write-Host "  Then open: http://localhost:3001" -ForegroundColor White
} else {
    Write-Host "✗ Fix the issues above before building." -ForegroundColor Red
}
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Cyan
