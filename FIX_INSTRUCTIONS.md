# Fix Instructions

## You're seeing the HTML formatting error because you haven't pulled the latest fixes yet.

### Run these commands in your PowerShell:

```powershell
# Navigate to your AD Suite folder
cd C:\Users\vagrant\tools\AD_SUITE_TESTING

# Pull the latest fixes from GitHub
git pull origin mod

# Now run the scan again (will work without errors)
.\Invoke-ADSuiteScan.ps1 -ChecksJsonPath .\checks.json -OutputDirectory .\out\test

# Open the dashboard
start .\ui\dashboard.html
# Then load: .\out\test\scan-results.json
```

## What was fixed:

1. **HTML Report Generation Error** - Fixed string formatting in `Modules/ADSuite.Adsi.psm1` line 1017
2. **Output Path Error** - Fixed relative path resolution in `Invoke-ADSuiteScan.ps1`
3. **Syntax Error** - Removed extra closing brace

## After pulling, your scan will complete successfully without errors!

---

## Alternative: If git pull doesn't work

If you get merge conflicts or issues, you can re-clone:

```powershell
# Go to parent directory
cd C:\Users\vagrant\tools

# Remove old folder
Remove-Item -Recurse -Force AD_SUITE_TESTING

# Clone fresh copy
git clone -b mod https://github.com/mudigolambharath256-max/AD_SUITE_TESTING.git

# Navigate to folder
cd AD_SUITE_TESTING

# Set execution policy
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Run scan
.\Invoke-ADSuiteScan.ps1 -ChecksJsonPath .\checks.json -OutputDirectory .\out\test
```
