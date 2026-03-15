# How to Run AD Security Suite Commands

## Quick Start Guide

### 1. Running the Web Application

#### Option A: Using the Batch File (Easiest)
```bash
# Navigate to the ad-suite-web folder
cd ad-suite-web

# Double-click START.bat or run:
START.bat
```

#### Option B: Using PowerShell
```powershell
# Navigate to the ad-suite-web folder
cd ad-suite-web

# Run the start script
.\install\Start-ADSuite.ps1
```

#### Option C: Manual Start
```powershell
# Navigate to backend folder
cd ad-suite-web\backend

# Start the server
node server.js
```

Then open your browser to: **http://localhost:3001**

---

### 2. Running Individual ADSI Check Scripts

#### Run a Single Check
```powershell
# Navigate to any check directory
cd Access_Control\ACC-001_Privileged_Users_adminCount1

# Run the ADSI script
.\adsi.ps1
```

#### Run All Checks in a Category
```powershell
# Run all Access Control checks
Get-ChildItem -Path "Access_Control" -Recurse -Filter "adsi.ps1" | ForEach-Object {
    Write-Host "Running: $($_.Directory.Name)" -ForegroundColor Cyan
    & $_.FullName
}
```

---

### 3. Running Recovery Scripts

#### Recover ADSI Files from Combined Scripts
```powershell
# Run the category-based recovery (recommended)
.\recover_by_category.ps1

# Or run the fast recovery
.\recover_adsi_fast.ps1
```

#### Fix Corrupted ADSI Files
```powershell
# Fix syntax errors in ADSI files
.\fix_corrupted_adsi.ps1
```

#### Append BloodHound Export Blocks
```powershell
# Add BloodHound export metadata to all ADSI files
.\append_bh_export.ps1 -SuiteRoot "C:\Users\acer\Downloads\AD_suiteXXX"
```

---

### 4. Running BloodHound Export

#### Export All Checks to BloodHound Format
```powershell
# Run the main BloodHound export script
.\bloodhound.ps1
```

This will:
- Execute all ADSI checks
- Export results to BloodHound-compatible JSON
- Save to: `C:\ADSuite_BloodHound\SESSION_<timestamp>\`

---

### 5. Running Validation Scripts

#### Check Script Syntax
```powershell
# Validate all ADSI scripts for syntax errors
.\comprehensive-validation.ps1
```

#### Test All Scripts
```powershell
# Run all scripts and check for errors
.\test-all-scripts.ps1
```

---

### 6. Docker Commands (Windows Containers)

#### Prerequisites Check
```powershell
# Check if Docker is ready for Windows containers
cd ad-suite-web\docker
.\windows-containers-check.ps1
```

#### Build and Run with Docker
```powershell
# Navigate to the project root
cd ad-suite-web

# Build and start the container
docker compose -f docker/docker-compose.yml up --build -d

# View logs
docker compose -f docker/docker-compose.yml logs -f

# Stop the container
docker compose -f docker/docker-compose.yml down
```

#### Development Mode with Live Reload
```powershell
# Start in development mode
docker compose -f docker/docker-compose.yml -f docker/docker-compose.dev.yml up
```

---

### 7. Common PowerShell Commands

#### Navigate Directories
```powershell
# Go to project root
cd C:\Users\acer\Downloads\AD_suiteXXX

# Go to web app
cd ad-suite-web

# Go back one level
cd ..
```

#### List Files
```powershell
# List all files in current directory
Get-ChildItem

# List only directories
Get-ChildItem -Directory

# List ADSI scripts recursively
Get-ChildItem -Recurse -Filter "adsi.ps1"
```

#### Run Scripts with Parameters
```powershell
# Run script with parameter
.\script.ps1 -ParameterName "value"

# Example: Recovery script with custom path
.\recover_by_category.ps1 -SuiteRoot "C:\Custom\Path"
```

#### Check Script Execution Policy
```powershell
# Check current execution policy
Get-ExecutionPolicy

# Set execution policy (if needed)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

### 8. Git Commands

#### Check Status
```powershell
git status
```

#### Add and Commit Changes
```powershell
# Add all changes
git add -A

# Commit with message
git commit -m "Your commit message"
```

#### Push to GitHub
```powershell
# Push to main branch
git push origin master:main

# Or if on main branch
git push origin main
```

#### Pull Latest Changes
```powershell
git pull origin main
```

---

### 9. Troubleshooting

#### Script Won't Run
```powershell
# Run with bypass execution policy
powershell -ExecutionPolicy Bypass -File .\script.ps1
```

#### Permission Denied
```powershell
# Run PowerShell as Administrator
# Right-click PowerShell icon → "Run as Administrator"
```

#### Port Already in Use
```powershell
# Find process using port 3001
netstat -ano | findstr :3001

# Kill the process (replace PID with actual process ID)
taskkill /PID <PID> /F
```

#### Node Modules Missing
```powershell
# Reinstall dependencies
cd ad-suite-web\backend
npm install

cd ..\frontend
npm install
```

---

### 10. Useful Shortcuts

#### Stop Running Script
- Press `Ctrl + C` in PowerShell

#### Clear Terminal
```powershell
cls
# or
Clear-Host
```

#### View Command History
```powershell
Get-History
```

#### Run Previous Command
- Press `↑` (Up Arrow) key

---

## Quick Reference Card

| Task | Command |
|------|---------|
| Start Web App | `cd ad-suite-web; START.bat` |
| Run Single Check | `cd <category>\<check>; .\adsi.ps1` |
| Recover ADSI Files | `.\recover_by_category.ps1` |
| Fix Syntax Errors | `.\fix_corrupted_adsi.ps1` |
| Export to BloodHound | `.\bloodhound.ps1` |
| Validate Scripts | `.\comprehensive-validation.ps1` |
| Docker Build | `docker compose -f docker/docker-compose.yml up --build` |
| Git Push | `git add -A; git commit -m "message"; git push origin master:main` |

---

## Need Help?

- Check the README.md in ad-suite-web folder for detailed setup instructions
- Review DOCK_WIN.md for Docker deployment details
- See recovery_status_report.md for recovery progress
- Check .env.example for configuration options

---

**Pro Tip**: Use Tab completion in PowerShell! Type the first few letters and press Tab to auto-complete file/folder names.
