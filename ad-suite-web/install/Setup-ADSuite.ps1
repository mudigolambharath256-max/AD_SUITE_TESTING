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
