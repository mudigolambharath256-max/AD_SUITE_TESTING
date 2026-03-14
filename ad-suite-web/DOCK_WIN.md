================================================================================
AD SECURITY SUITE — DEPLOYMENT SETUP
Docker (Windows Containers) + Native Windows Install
Kiro Prompt
================================================================================

READ EVERYTHING BEFORE WRITING ANY FILE.

This prompt adds two completely separate deployment methods to the project.
Neither method modifies any existing source code, any PowerShell script, any
React component, or any backend route. It only adds deployment files.

================================================================================
CRITICAL TECHNICAL CONTEXT — READ BEFORE ANY DOCKER WORK
================================================================================

This application CANNOT use Linux Docker containers. Here is why:

  1. All 3,715 check scripts (.ps1, .cs, .bat) use Windows-specific APIs:
       [ADSISearcher]        — Windows ADSI, does not exist on Linux
       [ADSI]"LDAP://..."    — Windows ADSI, does not exist on Linux
       Get-ADObject          — Requires ActiveDirectory PS module (Windows only)
       dsquery.exe           — Windows-only executable

  2. The terminal uses @lydell/node-pty which creates a Windows ConPTY.
     ConPTY is a Windows-only kernel feature.

  3. The C# engine compiles with csc.exe from .NET Framework (Windows-only).

THEREFORE: Docker MUST use Windows containers.
  Correct:   docker-compose with mcr.microsoft.com/powershell:windowsservercore-ltsc2022
  Incorrect: node:18-alpine or any Linux base image

Windows containers require:
  - Docker Desktop for Windows with "Switch to Windows containers" enabled
  - OR Docker Engine on Windows Server 2019/2022
  - The HOST machine must be Windows (domain-joined for AD script execution)

================================================================================
PART A — DOCKER (WINDOWS CONTAINERS)
================================================================================

Create these files in the git root of the project:

  docker/
    Dockerfile
    docker-compose.yml
    docker-compose.dev.yml
    .dockerignore
    windows-containers-check.ps1
  .env.example

────────────────────────────────────────────────────────────────────────────────
FILE: docker/Dockerfile
────────────────────────────────────────────────────────────────────────────────

# ────────────────────────────────────────────────────────────────────────────
# AD Security Suite — Windows Container
# Base: Windows Server Core + PowerShell
# Requires: Docker Desktop for Windows with Windows containers mode
#           The host machine must be domain-joined for AD script execution
# ────────────────────────────────────────────────────────────────────────────

# Stage 1: Build the React frontend
# Using a Windows base so we stay on one platform throughout
FROM mcr.microsoft.com/windows/servercore:ltsc2022 AS frontend-builder

# Install Node.js (LTS) silently
SHELL ["powershell", "-ExecutionPolicy", "Bypass", "-Command"]

RUN Invoke-WebRequest -Uri "https://nodejs.org/dist/v20.11.0/node-v20.11.0-x64.msi" `
    -OutFile "C:\\node-installer.msi"; `
    Start-Process msiexec.exe -Wait -ArgumentList '/I C:\\node-installer.msi /quiet /norestart'; `
    Remove-Item C:\\node-installer.msi

# Add node and npm to PATH
RUN $env:PATH = $env:PATH + ';C:\\Program Files\\nodejs'; `
    [Environment]::SetEnvironmentVariable('PATH', $env:PATH, 'Machine')

WORKDIR C:\\app

# Copy and build frontend
COPY frontend/package.json frontend/package-lock.json* ./frontend/
RUN cd frontend; npm ci --prefer-offline

COPY frontend/ ./frontend/
RUN cd frontend; npm run build

# ────────────────────────────────────────────────────────────────────────────
# Stage 2: Production runtime image
# Uses the PowerShell image which includes PowerShell 7 + .NET
# PowerShell 7 is compatible with the ADSI scripts
# ────────────────────────────────────────────────────────────────────────────
FROM mcr.microsoft.com/powershell:windowsservercore-ltsc2022

SHELL ["powershell", "-ExecutionPolicy", "Bypass", "-Command"]

# Install Node.js
RUN Invoke-WebRequest -Uri "https://nodejs.org/dist/v20.11.0/node-v20.11.0-x64.msi" `
    -OutFile "C:\\node-installer.msi"; `
    Start-Process msiexec.exe -Wait -ArgumentList '/I C:\\node-installer.msi /quiet /norestart'; `
    Remove-Item C:\\node-installer.msi

# Update PATH for the session
RUN $env:PATH = $env:PATH + ';C:\\Program Files\\nodejs'; `
    [Environment]::SetEnvironmentVariable('PATH', $env:PATH, 'Machine')

WORKDIR C:\\app

# ── Install backend dependencies ─────────────────────────────────────────
COPY backend/package.json backend/package-lock.json* ./backend/
RUN cd backend; npm ci --prefer-offline --omit=dev; `
    Write-Host "Backend dependencies installed"

# ── Copy backend source ───────────────────────────────────────────────────
COPY backend/ ./backend/

# ── Copy built frontend from Stage 1 ─────────────────────────────────────
# The backend serves the frontend dist as static files
COPY --from=frontend-builder C:/app/frontend/dist ./backend/public

# ── Copy the AD suite scripts ─────────────────────────────────────────────
# The checks are read-only — never modify these in the container
COPY AD-Suite-scripts-main/ ./AD-Suite-scripts-main/

# ── Create runtime directories ────────────────────────────────────────────
RUN New-Item -ItemType Directory -Force -Path C:\app\data | Out-Null; `
    New-Item -ItemType Directory -Force -Path C:\app\reports | Out-Null

# ── Environment defaults (override via docker-compose or .env) ───────────
ENV NODE_ENV=production
ENV PORT=3001
ENV SUITE_ROOT_PATH=C:\app\AD-Suite-scripts-main
ENV DB_PATH=C:\app\data\database.db
ENV REPORTS_PATH=C:\app\reports

# ── Health check ──────────────────────────────────────────────────────────
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 `
    CMD powershell -Command "try { Invoke-RestMethod http://localhost:3001/api/health -TimeoutSec 5; exit 0 } catch { exit 1 }"

# ── Expose port ───────────────────────────────────────────────────────────
EXPOSE 3001

# ── Start the backend (which also serves the built frontend) ─────────────
CMD ["node", "C:\\app\\backend\\server.js"]

────────────────────────────────────────────────────────────────────────────────
FILE: docker/docker-compose.yml   (Production)
────────────────────────────────────────────────────────────────────────────────

# AD Security Suite — Docker Compose (Windows Containers)
#
# REQUIREMENTS:
#   - Docker Desktop for Windows with Windows containers mode enabled
#   - Host machine MUST be domain-joined for AD script execution
#   - Run from the git root: docker-compose -f docker/docker-compose.yml up
#
# DOMAIN ACCESS:
#   The container inherits the host's network and can reach domain controllers.
#   AD scripts run as the container's process user. For best results, run the
#   container with a service account that has AD read access.
#
# Usage:
#   docker-compose -f docker/docker-compose.yml up -d
#   Open browser: http://localhost:3001
#   Stop:         docker-compose -f docker/docker-compose.yml down

version: '3.8'

services:
  ad-suite:
    build:
      context: ..
      dockerfile: docker/Dockerfile
    image: ad-security-suite:latest
    container_name: ad-suite

    # ── Port mapping ──────────────────────────────────────────────────────
    ports:
      - "${APP_PORT:-3001}:3001"

    # ── Persistent volumes ─────────────────────────────────────────────────
    # SQLite database and scan reports persist across container restarts
    volumes:
      - ad-suite-data:C:/app/data
      - ad-suite-reports:C:/app/reports
      # Optional: mount host suite folder instead of using the baked-in copy
      # This lets you update scripts without rebuilding the image
      # - ../AD-Suite-scripts-main:C:/app/AD-Suite-scripts-main:ro

    # ── Environment variables ──────────────────────────────────────────────
    environment:
      - NODE_ENV=production
      - PORT=3001
      - SUITE_ROOT_PATH=C:\app\AD-Suite-scripts-main
      - DB_PATH=C:\app\data\database.db
      - REPORTS_PATH=C:\app\reports
      # Set your domain info here or in .env file:
      - DEFAULT_DOMAIN=${DEFAULT_DOMAIN:-}
      - DEFAULT_DC_IP=${DEFAULT_DC_IP:-}

    # ── Use host network mode for AD access ───────────────────────────────
    # host network mode gives the container direct access to the host's
    # network interfaces and Kerberos tickets — needed for ADSI/LDAP queries
    # NOTE: With host networking, the port mapping above is ignored.
    #       Access the app at http://localhost:3001 directly.
    network_mode: host

    # ── Resource limits ────────────────────────────────────────────────────
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '2.0'

    # ── Restart policy ─────────────────────────────────────────────────────
    restart: unless-stopped

    # ── Logging ────────────────────────────────────────────────────────────
    logging:
      driver: json-file
      options:
        max-size: "50m"
        max-file: "3"

volumes:
  ad-suite-data:
    name: ad-suite-data
  ad-suite-reports:
    name: ad-suite-reports

────────────────────────────────────────────────────────────────────────────────
FILE: docker/docker-compose.dev.yml   (Development — live reload)
────────────────────────────────────────────────────────────────────────────────

# Development override — mounts source code live, enables hot reload
#
# Usage (from git root):
#   docker-compose -f docker/docker-compose.yml -f docker/docker-compose.dev.yml up
#
# This mounts frontend/src and backend/ as live volumes so code changes
# are reflected without rebuilding the image.

version: '3.8'

services:
  ad-suite:
    build:
      target: frontend-builder    # override: re-run both stages for dev
    environment:
      - NODE_ENV=development
    volumes:
      # Live mount backend source (nodemon watches for changes)
      - ../backend:/app/backend
      # Live mount frontend source (vite dev server watches for changes)
      - ../frontend:/app/frontend
      # Keep node_modules from the image (do not mount over them)
      - /app/backend/node_modules
      - /app/frontend/node_modules
      - ad-suite-data:C:/app/data
      - ad-suite-reports:C:/app/reports
    command: >
      powershell -Command
        "cd C:\app\backend;
         npm install -g nodemon;
         Start-Job { cd C:\app\frontend; npm run dev -- --host 0.0.0.0 --port 5173 };
         nodemon server.js"
    ports:
      - "3001:3001"
      - "5173:5173"    # Vite dev server

────────────────────────────────────────────────────────────────────────────────
FILE: docker/.dockerignore
────────────────────────────────────────────────────────────────────────────────

# Git
.git
.gitignore
**/.git

# Node
**/node_modules
**/npm-debug.log*

# Build outputs
frontend/dist
frontend/.vite

# Runtime data — these are created in the container, not baked in
backend/database.db
backend/reports/
data/
reports/

# Editor
**/.vscode
**/.idea
**/*.suo
**/*.user

# OS
**/Thumbs.db
**/.DS_Store
**/desktop.ini

# Docs and dev files
*.md
docs/
docker/

# Test files
**/*.test.*
**/*.spec.*

────────────────────────────────────────────────────────────────────────────────
FILE: docker/windows-containers-check.ps1
────────────────────────────────────────────────────────────────────────────────

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

────────────────────────────────────────────────────────────────────────────────
FILE: .env.example   (copy to .env and edit)
────────────────────────────────────────────────────────────────────────────────

# ────────────────────────────────────────────────────────────────────────────
# AD Security Suite — Environment Variables
# Copy this file to .env and fill in your values.
# .env is gitignored — never commit it.
# ────────────────────────────────────────────────────────────────────────────

# ── Application port ──────────────────────────────────────────────────────
APP_PORT=3001

# ── Suite scripts location ─────────────────────────────────────────────────
# Docker: C:\app\AD-Suite-scripts-main (default — baked into image)
# Native Windows: full path to AD-Suite-scripts-main on your machine
SUITE_ROOT_PATH=

# ── Database location ──────────────────────────────────────────────────────
# Docker: C:\app\data\database.db (persisted in Docker volume)
# Native Windows: .\backend\database.db (relative to backend/)
DB_PATH=

# ── Reports output directory ───────────────────────────────────────────────
# Docker: C:\app\reports
# Native Windows: .\backend\reports
REPORTS_PATH=

# ── Default target domain (optional — can be set per-scan in the UI) ──────
DEFAULT_DOMAIN=
DEFAULT_DC_IP=

# ── Node environment ───────────────────────────────────────────────────────
NODE_ENV=production

# ── Anthropic API key (for LLM attack path analysis on the Attack Path page)
# Leave empty to disable LLM features
ANTHROPIC_API_KEY=

================================================================================
PART B — NATIVE WINDOWS INSTALLATION (NO DOCKER)
================================================================================

Create these files in the git root:

  install/
    Setup-ADSuite.ps1      ← automated prerequisite check + setup
    Start-ADSuite.ps1      ← start the application
    Stop-ADSuite.ps1       ← stop the application
    Uninstall-ADSuite.ps1  ← clean uninstall
  start.bat                ← double-click to start (calls Start-ADSuite.ps1)
  stop.bat                 ← double-click to stop

────────────────────────────────────────────────────────────────────────────────
FILE: install/Setup-ADSuite.ps1
────────────────────────────────────────────────────────────────────────────────

<#
.SYNOPSIS
    AD Security Suite — Automated Setup Script
    Installs all prerequisites and configures the application.

.DESCRIPTION
    Run this script once after cloning the repository.
    It will:
      1. Check and install Node.js if missing
      2. Check PowerShell version
      3. Run npm install for backend and frontend
      4. Create the .env configuration file
      5. Verify the suite scripts folder
      6. Confirm the setup is complete

.NOTES
    - Run from the git root directory (where this script's parent folder is)
    - Requires internet access to download Node.js if not installed
    - Does NOT require administrator privileges (unless installing Node.js)
    - Safe to run multiple times
#>

Set-StrictMode -Off
$ErrorActionPreference = 'Stop'
$ScriptRoot = Split-Path $PSScriptRoot -Parent  # git root

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  AD Security Suite — Setup" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

$errors   = @()
$warnings = @()

# ── STEP 1: Check PowerShell version ────────────────────────────────────
Write-Host "[1/7] Checking PowerShell version..." -ForegroundColor Yellow
$psVersion = $PSVersionTable.PSVersion
Write-Host "  PowerShell $($psVersion.Major).$($psVersion.Minor) found" -ForegroundColor Gray
if ($psVersion.Major -lt 5) {
    $errors += "PowerShell 5.1 or later is required. Current: $($psVersion.Major).$($psVersion.Minor). Download from https://aka.ms/wmf5download"
} else {
    Write-Host "  OK: PowerShell $($psVersion.Major).$($psVersion.Minor)" -ForegroundColor Green
}

# ── STEP 2: Check Windows version ────────────────────────────────────────
Write-Host "`n[2/7] Checking Windows version..." -ForegroundColor Yellow
$os = Get-WmiObject -Class Win32_OperatingSystem
$osBuild = [int]($os.BuildNumber)
Write-Host "  $($os.Caption) (Build $osBuild)" -ForegroundColor Gray
if ($osBuild -lt 17763) {  # Windows Server 2019 / Windows 10 1809
    $warnings += "Windows build $osBuild detected. Windows Server 2019 / Windows 10 v1809 or later recommended."
} else {
    Write-Host "  OK: $($os.Caption)" -ForegroundColor Green
}

# ── STEP 3: Check domain membership ──────────────────────────────────────
Write-Host "`n[3/7] Checking domain membership..." -ForegroundColor Yellow
$cs = Get-WmiObject -Class Win32_ComputerSystem
if ($cs.PartOfDomain) {
    Write-Host "  OK: Joined to domain: $($cs.Domain)" -ForegroundColor Green
} else {
    $warnings += "Machine is NOT domain-joined. AD scripts will return empty results. Join this machine to the target domain before running scans."
    Write-Host "  WARN: Not domain-joined" -ForegroundColor Yellow
}

# ── STEP 4: Check / Install Node.js ──────────────────────────────────────
Write-Host "`n[4/7] Checking Node.js..." -ForegroundColor Yellow
$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
    $nodeVer = node --version
    $nodeNum = [int]($nodeVer -replace 'v(\d+).*','$1')
    if ($nodeNum -ge 18) {
        Write-Host "  OK: Node.js $nodeVer" -ForegroundColor Green
    } else {
        Write-Host "  WARN: Node.js $nodeVer found but v18+ is required." -ForegroundColor Yellow
        $needsNodeInstall = $true
    }
} else {
    Write-Host "  Node.js not found. Installing..." -ForegroundColor Yellow
    $needsNodeInstall = $true
}

if ($needsNodeInstall -eq $true) {
    Write-Host "  Downloading Node.js v20 LTS..." -ForegroundColor Yellow
    $nodeUrl = "https://nodejs.org/dist/v20.11.0/node-v20.11.0-x64.msi"
    $nodeMsi = "$env:TEMP\node-installer.msi"
    try {
        # Try winget first (faster, no UAC if already installed)
        $winget = Get-Command winget -ErrorAction SilentlyContinue
        if ($winget) {
            Write-Host "  Installing via winget..." -ForegroundColor Gray
            winget install --id OpenJS.NodeJS.LTS --silent --accept-source-agreements --accept-package-agreements
        } else {
            # Fall back to MSI download
            Write-Host "  Downloading MSI installer..." -ForegroundColor Gray
            Invoke-WebRequest -Uri $nodeUrl -OutFile $nodeMsi -UseBasicParsing
            Write-Host "  Running installer (requires elevation)..." -ForegroundColor Gray
            Start-Process msiexec.exe -Wait -ArgumentList "/I `"$nodeMsi`" /quiet /norestart" -Verb RunAs
            Remove-Item $nodeMsi -ErrorAction SilentlyContinue
        }
        # Refresh PATH
        $env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('PATH', 'User')
        $verAfter = node --version
        Write-Host "  OK: Node.js $verAfter installed" -ForegroundColor Green
    } catch {
        $errors += "Failed to install Node.js automatically: $_`n  Please install manually from https://nodejs.org and re-run this script."
    }
}

# ── STEP 5: Locate suite scripts folder ──────────────────────────────────
Write-Host "`n[5/7] Locating AD suite scripts..." -ForegroundColor Yellow
$suitePath = Join-Path $ScriptRoot 'AD-Suite-scripts-main'
if (Test-Path $suitePath) {
    $catCount = (Get-ChildItem $suitePath -Directory).Count
    Write-Host "  OK: Found at $suitePath ($catCount categories)" -ForegroundColor Green
} else {
    # Try one level up (in case the clone structure is different)
    $suitePath2 = Join-Path (Split-Path $ScriptRoot -Parent) 'AD-Suite-scripts-main'
    if (Test-Path $suitePath2) {
        $suitePath = $suitePath2
        Write-Host "  OK: Found at $suitePath" -ForegroundColor Green
    } else {
        $warnings += "AD-Suite-scripts-main/ not found at $suitePath. After setup, go to Settings and set the Suite Root Path manually."
        $suitePath = $suitePath  # keep the expected path for .env
        Write-Host "  WARN: Not found — set path in Settings after startup" -ForegroundColor Yellow
    }
}

# ── STEP 6: npm install (backend + frontend) ──────────────────────────────
Write-Host "`n[6/7] Installing npm packages..." -ForegroundColor Yellow

$backendDir  = Join-Path $ScriptRoot 'backend'
$frontendDir = Join-Path $ScriptRoot 'frontend'

if (-not (Test-Path $backendDir))  { $errors += "backend/ directory not found at $backendDir"  }
if (-not (Test-Path $frontendDir)) { $errors += "frontend/ directory not found at $frontendDir" }

if ($errors.Count -eq 0) {
    Write-Host "  Installing backend dependencies..." -ForegroundColor Gray
    Push-Location $backendDir
    try {
        npm install --prefer-offline 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
        if ($LASTEXITCODE -ne 0) { throw "npm install failed for backend" }
        Write-Host "  OK: Backend packages installed" -ForegroundColor Green
    } catch {
        $errors += "Backend npm install failed: $_"
    } finally {
        Pop-Location
    }

    Write-Host "  Installing frontend dependencies..." -ForegroundColor Gray
    Push-Location $frontendDir
    try {
        npm install --prefer-offline 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
        if ($LASTEXITCODE -ne 0) { throw "npm install failed for frontend" }
        Write-Host "  OK: Frontend packages installed" -ForegroundColor Green
    } catch {
        $errors += "Frontend npm install failed: $_"
    } finally {
        Pop-Location
    }
}

# ── STEP 7: Create .env file ──────────────────────────────────────────────
Write-Host "`n[7/7] Creating configuration file..." -ForegroundColor Yellow
$envFile    = Join-Path $ScriptRoot '.env'
$envExample = Join-Path $ScriptRoot '.env.example'

if (Test-Path $envFile) {
    Write-Host "  .env already exists — skipping (not overwriting)" -ForegroundColor Gray
} else {
    $dbPath      = Join-Path $backendDir 'database.db'
    $reportsPath = Join-Path $backendDir 'reports'

    $envContent = @"
# AD Security Suite — Environment Configuration
# Generated by Setup-ADSuite.ps1 on $(Get-Date -Format 'yyyy-MM-dd HH:mm')

APP_PORT=3001
NODE_ENV=production

SUITE_ROOT_PATH=$suitePath
DB_PATH=$dbPath
REPORTS_PATH=$reportsPath

DEFAULT_DOMAIN=
DEFAULT_DC_IP=

ANTHROPIC_API_KEY=
"@
    Set-Content -Path $envFile -Value $envContent -Encoding UTF8
    Write-Host "  OK: .env created at $envFile" -ForegroundColor Green
    Write-Host "  TIP: Edit .env to add DEFAULT_DOMAIN and DEFAULT_DC_IP" -ForegroundColor Gray
}

# ── SUMMARY ────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

if ($errors.Count -gt 0) {
    Write-Host "SETUP FAILED — Fix these errors and re-run:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "  ✗ $_" -ForegroundColor Red }
    Write-Host ""
    exit 1
}

if ($warnings.Count -gt 0) {
    Write-Host "SETUP COMPLETE WITH WARNINGS:" -ForegroundColor Yellow
    $warnings | ForEach-Object { Write-Host "  ⚠ $_" -ForegroundColor Yellow }
} else {
    Write-Host "SETUP COMPLETE" -ForegroundColor Green
}

Write-Host ""
Write-Host "TO START THE APPLICATION:" -ForegroundColor White
Write-Host "  Option A (easy):    Double-click start.bat" -ForegroundColor Cyan
Write-Host "  Option B (PS):      .\install\Start-ADSuite.ps1" -ForegroundColor Cyan
Write-Host "  Option C (manual):  cd backend; node server.js" -ForegroundColor Gray
Write-Host ""
Write-Host "Then open:  http://localhost:3001" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

────────────────────────────────────────────────────────────────────────────────
FILE: install/Start-ADSuite.ps1
────────────────────────────────────────────────────────────────────────────────

<#
.SYNOPSIS
    Start the AD Security Suite web application.
    Starts backend and frontend concurrently in separate windows.
#>

Set-StrictMode -Off
$ScriptRoot = Split-Path $PSScriptRoot -Parent   # git root

# ── Load .env ─────────────────────────────────────────────────────────────
$envFile = Join-Path $ScriptRoot '.env'
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#=]+)=(.*)$') {
            $key = $Matches[1].Trim()
            $val = $Matches[2].Trim()
            if ($key -and $val -and -not [Environment]::GetEnvironmentVariable($key)) {
                [Environment]::SetEnvironmentVariable($key, $val, 'Process')
            }
        }
    }
}

$port        = $env:APP_PORT ?? '3001'
$backendDir  = Join-Path $ScriptRoot 'backend'
$frontendDir = Join-Path $ScriptRoot 'frontend'
$nodeEnv     = $env:NODE_ENV ?? 'development'

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  AD Security Suite — Starting" -ForegroundColor White
Write-Host "  Mode: $nodeEnv | Port: $port" -ForegroundColor Gray
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

# ── Prerequisite checks ────────────────────────────────────────────────────
if (-not (Test-Path $backendDir)) {
    Write-Host "ERROR: backend/ not found. Run Setup-ADSuite.ps1 first." -ForegroundColor Red
    exit 1
}
if (-not (Test-Path (Join-Path $backendDir 'node_modules'))) {
    Write-Host "ERROR: node_modules missing. Run Setup-ADSuite.ps1 first." -ForegroundColor Red
    exit 1
}

# ── Choose start mode ────────────────────────────────────────────────────
if ($nodeEnv -eq 'production') {
    # ── PRODUCTION: backend serves built frontend static files ────────────
    # First build the frontend if dist/ doesn't exist
    $distDir = Join-Path $frontendDir 'dist'
    if (-not (Test-Path $distDir)) {
        Write-Host "Building frontend for production..." -ForegroundColor Yellow
        Push-Location $frontendDir
        npm run build
        Pop-Location
    }

    Write-Host "`nStarting backend (production mode)..." -ForegroundColor Green
    Write-Host "  App will be available at: http://localhost:$port" -ForegroundColor White
    Write-Host "  Press Ctrl+C to stop" -ForegroundColor Gray
    Write-Host ""

    # Save PID for Stop-ADSuite.ps1
    $pidFile = Join-Path $ScriptRoot '.ad-suite.pid'
    $env:NODE_ENV = 'production'

    Push-Location $backendDir
    $proc = Start-Process node -ArgumentList 'server.js' -PassThru -NoNewWindow
    $proc.Id | Set-Content $pidFile
    Write-Host "  Backend PID: $($proc.Id) (saved to .ad-suite.pid)" -ForegroundColor Gray

    # Open browser after 3 seconds
    Start-Sleep -Seconds 3
    Start-Process "http://localhost:$port"

    $proc.WaitForExit()
    Pop-Location

} else {
    # ── DEVELOPMENT: run backend + vite dev server concurrently ──────────
    Write-Host "`nStarting in DEVELOPMENT mode..." -ForegroundColor Yellow
    Write-Host "  Backend:   http://localhost:$port/api" -ForegroundColor White
    Write-Host "  Frontend:  http://localhost:5173" -ForegroundColor White
    Write-Host "  Hot reload: ENABLED" -ForegroundColor Gray
    Write-Host ""

    # Start backend in a new window
    $backendWindow = Start-Process powershell -ArgumentList @(
        "-ExecutionPolicy", "Bypass", "-NoProfile", "-NoLogo",
        "-Command", "cd '$backendDir'; `$env:NODE_ENV='development'; node server.js"
    ) -PassThru -WindowStyle Normal

    Start-Sleep -Seconds 2

    # Start frontend Vite dev server in another window
    $frontendWindow = Start-Process powershell -ArgumentList @(
        "-ExecutionPolicy", "Bypass", "-NoProfile", "-NoLogo",
        "-Command", "cd '$frontendDir'; npm run dev"
    ) -PassThru -WindowStyle Normal

    # Save PIDs
    "$($backendWindow.Id)`n$($frontendWindow.Id)" | Set-Content (Join-Path $ScriptRoot '.ad-suite.pid')

    Write-Host "  Started! Backend PID: $($backendWindow.Id), Frontend PID: $($frontendWindow.Id)" -ForegroundColor Green

    # Open browser after 4 seconds (vite takes a moment)
    Start-Sleep -Seconds 4
    Start-Process "http://localhost:5173"

    Write-Host ""
    Write-Host "Both windows are running. Close them or run Stop-ADSuite.ps1 to stop." -ForegroundColor Gray
}

────────────────────────────────────────────────────────────────────────────────
FILE: install/Stop-ADSuite.ps1
────────────────────────────────────────────────────────────────────────────────

<#
.SYNOPSIS
    Stop the AD Security Suite application processes.
#>

$ScriptRoot = Split-Path $PSScriptRoot -Parent
$pidFile    = Join-Path $ScriptRoot '.ad-suite.pid'

Write-Host "Stopping AD Security Suite..." -ForegroundColor Yellow

if (Test-Path $pidFile) {
    Get-Content $pidFile | ForEach-Object {
        $pid = [int]$_.Trim()
        if ($pid -gt 0) {
            try {
                Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
                Write-Host "  Stopped PID $pid" -ForegroundColor Green
            } catch {
                Write-Host "  PID $pid already stopped" -ForegroundColor Gray
            }
        }
    }
    Remove-Item $pidFile -ErrorAction SilentlyContinue
} else {
    Write-Host "  No PID file found — killing all node.exe processes related to the suite..." -ForegroundColor Yellow
    Get-Process node -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowTitle -match 'AD' -or $_.CommandLine -match 'server.js' } |
        ForEach-Object {
            Stop-Process -Id $_.Id -Force
            Write-Host "  Stopped node PID $($_.Id)" -ForegroundColor Green
        }
}

Write-Host "Done." -ForegroundColor Green

────────────────────────────────────────────────────────────────────────────────
FILE: install/Uninstall-ADSuite.ps1
────────────────────────────────────────────────────────────────────────────────

<#
.SYNOPSIS
    Clean uninstall of AD Security Suite.
    Removes node_modules, build artifacts, database, and config.
    Does NOT delete the source code or suite scripts.
#>

$ScriptRoot = Split-Path $PSScriptRoot -Parent

Write-Host "`nAD Security Suite — Uninstall" -ForegroundColor Red
Write-Host "This will remove: node_modules, build output, database, .env, PID file" -ForegroundColor Yellow
$confirm = Read-Host "Type 'yes' to continue"
if ($confirm -ne 'yes') { Write-Host "Cancelled."; exit 0 }

# Stop first
& (Join-Path $PSScriptRoot 'Stop-ADSuite.ps1')

$paths = @(
    "backend\node_modules",
    "frontend\node_modules",
    "frontend\dist",
    "frontend\.vite",
    "backend\database.db",
    "backend\reports",
    ".env",
    ".ad-suite.pid"
)

foreach ($rel in $paths) {
    $full = Join-Path $ScriptRoot $rel
    if (Test-Path $full) {
        Remove-Item $full -Recurse -Force
        Write-Host "  Removed: $rel" -ForegroundColor Gray
    }
}

Write-Host "`nUninstall complete. Source code and suite scripts are untouched." -ForegroundColor Green

────────────────────────────────────────────────────────────────────────────────
FILE: start.bat   (double-click shortcut)
────────────────────────────────────────────────────────────────────────────────

@echo off
title AD Security Suite
echo Starting AD Security Suite...
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0install\Start-ADSuite.ps1"
pause

────────────────────────────────────────────────────────────────────────────────
FILE: stop.bat   (double-click shortcut)
────────────────────────────────────────────────────────────────────────────────

@echo off
title AD Security Suite - Stop
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0install\Stop-ADSuite.ps1"
pause

================================================================================
PART C — GIT CONFIGURATION
================================================================================

────────────────────────────────────────────────────────────────────────────────
FILE: .gitignore   (create or append — do not remove any existing entries)
────────────────────────────────────────────────────────────────────────────────

# ── Runtime data — never commit these ─────────────────────────────────────
.env
.ad-suite.pid
backend/database.db
backend/reports/
data/
reports/
uploads/
uploads/adexplorer/

# ── Build outputs ──────────────────────────────────────────────────────────
frontend/dist/
frontend/.vite/

# ── Node ───────────────────────────────────────────────────────────────────
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.npm

# ── OS ─────────────────────────────────────────────────────────────────────
.DS_Store
Thumbs.db
desktop.ini
ehthumbs.db

# ── Editor ─────────────────────────────────────────────────────────────────
.vscode/settings.json
.idea/
*.suo
*.user
*.userosscache
*.sln.docstates

# ── Docker runtime ─────────────────────────────────────────────────────────
docker/data/
docker/reports/

# ── Temp files ─────────────────────────────────────────────────────────────
*.tmp
*.temp
*.log

────────────────────────────────────────────────────────────────────────────────
UPDATE: backend/server.js  (ADD one health check endpoint only)
────────────────────────────────────────────────────────────────────────────────

Add this single route to backend/server.js. Find the existing route registrations
and add this line near them. Do NOT change anything else.

  // Health check endpoint (used by Docker HEALTHCHECK and monitoring)
  app.get('/api/health', (req, res) => {
    res.json({
      status:  'ok',
      time:    new Date().toISOString(),
      uptime:  process.uptime(),
      memory:  process.memoryUsage().heapUsed,
      version: process.env.npm_package_version || '1.0.0',
    });
  });

────────────────────────────────────────────────────────────────────────────────
UPDATE: backend/server.js  (ADD static file serving for production mode)
────────────────────────────────────────────────────────────────────────────────

In production, the backend serves the built React frontend.
Add this block to server.js AFTER all API routes but BEFORE the server.listen():

  // ── Serve frontend in production ────────────────────────────────────────
  if (process.env.NODE_ENV === 'production') {
    const path       = require('path');
    const frontendDist = path.join(__dirname, 'public');   // copy of frontend/dist
    const fs         = require('fs');

    if (fs.existsSync(frontendDist)) {
      app.use(express.static(frontendDist));
      // SPA fallback: any route not matched by API returns index.html
      app.get('*', (req, res) => {
        res.sendFile(path.join(frontendDist, 'index.html'));
      });
      console.log('[Server] Serving frontend from', frontendDist);
    } else {
      console.warn('[Server] Production mode but frontend/dist not found at', frontendDist);
      console.warn('[Server] Run: cd frontend && npm run build, then copy dist/ to backend/public/');
    }
  }

================================================================================
PART D — ROOT package.json (convenience scripts)
================================================================================

Create or update the root package.json with convenience scripts:

  {
    "name": "ad-security-suite",
    "version": "1.0.0",
    "description": "Active Directory Security Assessment Platform",
    "private": true,
    "scripts": {
      "setup":   "powershell -ExecutionPolicy Bypass -File install/Setup-ADSuite.ps1",
      "start":   "powershell -ExecutionPolicy Bypass -File install/Start-ADSuite.ps1",
      "stop":    "powershell -ExecutionPolicy Bypass -File install/Stop-ADSuite.ps1",
      "dev":     "npm-run-all --parallel dev:backend dev:frontend",
      "dev:backend":  "cd backend && node server.js",
      "dev:frontend": "cd frontend && npm run dev",
      "build":   "cd frontend && npm run build",
      "docker:check": "powershell -ExecutionPolicy Bypass -File docker/windows-containers-check.ps1",
      "docker:up":    "docker compose -f docker/docker-compose.yml up --build -d",
      "docker:down":  "docker compose -f docker/docker-compose.yml down",
      "docker:logs":  "docker compose -f docker/docker-compose.yml logs -f"
    },
    "devDependencies": {
      "npm-run-all": "^4.1.5"
    }
  }

Install the devDependency: npm install --save-dev npm-run-all  (in the root)

================================================================================
PART E — INSTALLATION DOCUMENTATION
================================================================================

────────────────────────────────────────────────────────────────────────────────
FILE: INSTALL.md   (create in git root)
────────────────────────────────────────────────────────────────────────────────

# AD Security Suite — Installation Guide

## Requirements

- Windows 10/11 or Windows Server 2019/2022
- Domain-joined machine (required for AD script execution)
- Current domain user with AD read permissions
- Internet access for first-time setup (downloads Node.js if missing)

---

## Method 1 — Native Windows (Recommended)

### Step 1: Clone the repository
```powershell
git clone https://github.com/your-org/ad-security-suite.git
cd ad-security-suite
```

### Step 2: Run setup (one time only)
```powershell
powershell -ExecutionPolicy Bypass -File install\Setup-ADSuite.ps1
```

This installs Node.js (if missing), runs npm install for backend and
frontend, and creates a `.env` configuration file.

### Step 3: Configure (optional)
Edit `.env` in the project root:
```
DEFAULT_DOMAIN=your.domain.local
DEFAULT_DC_IP=192.168.1.10
```

### Step 4: Start the application
```
Double-click start.bat
```
Or from PowerShell:
```powershell
.\install\Start-ADSuite.ps1
```

The browser opens automatically at **http://localhost:3001**

### Step 5: Configure suite path (first run)
1. Go to **Settings**
2. Set Suite Root Path to the `AD-Suite-scripts-main` folder
3. Click **Validate** — should show 775 checks

### Stop the application
```
Double-click stop.bat
```

---

## Method 2 — Docker (Windows Containers)

> **Requires:** Docker Desktop for Windows with Windows containers mode enabled.
> Right-click the Docker Desktop tray icon → **Switch to Windows containers**

### Step 1: Verify Docker is ready
```powershell
powershell -ExecutionPolicy Bypass -File docker\windows-containers-check.ps1
```
All checks must pass before proceeding.

### Step 2: Clone and build
```powershell
git clone https://github.com/your-org/ad-security-suite.git
cd ad-security-suite
docker compose -f docker/docker-compose.yml up --build -d
```
The first build takes 5-10 minutes (downloads Windows base image ~4GB).

### Step 3: Open the application
```
http://localhost:3001
```

### Step 4: Configure suite path in Settings
Suite path inside the container: `C:\app\AD-Suite-scripts-main`

### Useful Docker commands
```powershell
# View logs
docker compose -f docker/docker-compose.yml logs -f

# Stop
docker compose -f docker/docker-compose.yml down

# Rebuild after code changes
docker compose -f docker/docker-compose.yml up --build -d

# Enter the container for debugging
docker exec -it ad-suite powershell
```

### Data persistence
The database and scan reports are stored in Docker named volumes:
- `ad-suite-data`    → SQLite database
- `ad-suite-reports` → PDF/JSON/CSV exports

These persist across container restarts. To reset:
```powershell
docker compose -f docker/docker-compose.yml down -v
```

---

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| 0 findings from scans | Machine not domain-joined | Join machine to target AD domain |
| 0 findings from scans | Wrong suite path | Settings → set correct path → Validate |
| PowerShell error on scan | Execution policy | Setup script sets -ExecutionPolicy Bypass |
| Port 3001 already in use | Another process | Edit APP_PORT in .env |
| Docker build fails | Linux containers mode | Switch to Windows containers in Docker Desktop |
| Docker scripts return empty | Container network | Ensure network_mode: host in docker-compose.yml |

================================================================================
FILES CREATED (summary)
================================================================================

NEW files — create all of these:

  docker/
    Dockerfile                          ← Windows container build
    docker-compose.yml                  ← Production compose
    docker-compose.dev.yml              ← Dev compose with live reload
    .dockerignore                       ← Build context exclusions
    windows-containers-check.ps1        ← Pre-flight validation script

  install/
    Setup-ADSuite.ps1                   ← One-time setup (Node.js + npm install)
    Start-ADSuite.ps1                   ← Start backend + frontend
    Stop-ADSuite.ps1                    ← Stop all processes
    Uninstall-ADSuite.ps1               ← Clean uninstall

  start.bat                             ← Double-click to start
  stop.bat                              ← Double-click to stop
  .env.example                          ← Environment variable template
  .gitignore                            ← (create or append)
  INSTALL.md                            ← User-facing install guide
  package.json                          ← Root convenience scripts (create/update)

MODIFIED files — surgical additions only:

  backend/server.js
    ← ADD: GET /api/health route (3 lines)
    ← ADD: static file serving block for production mode (8 lines)
    ← DO NOT change any other routes, middleware, or logic

================================================================================
DO NOT TOUCH
================================================================================

  All 3,715 PowerShell/C#/CMD scripts in AD-Suite-scripts-main/
  frontend/src/**         (no component changes)
  backend/routes/**       (no route changes)
  backend/executor.js     (no changes)
  backend/terminalServer.js (no changes)
  vite.config.js
  tailwind.config.js
  Any colour, layout, or feature code

================================================================================