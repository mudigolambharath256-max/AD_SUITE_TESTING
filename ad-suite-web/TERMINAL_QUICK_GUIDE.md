# PowerShell Terminal - Quick User Guide

## Overview
The RunScans page now includes an interactive PowerShell terminal drawer at the bottom. Use it to test AD connectivity, verify credentials, and run diagnostic commands before committing to a full scan.

## How to Use

### Opening the Terminal
1. Navigate to the **Run Scans** page
2. Look for the **PS Terminal** button at the bottom-right
3. Click it to open the terminal drawer (slides up with animation)
4. Wait ~2 seconds for PowerShell to initialize

### Drawer Controls (Header Buttons)
- **Inject Context** - Re-injects domain/IP variables (only visible when domain/IP set and terminal ready)
- **Reconnect** - Starts a new PowerShell session (visible when disconnected/closed)
- **Clear** (trash icon) - Clears terminal output (keeps session alive)
- **Minimize** (minus icon) - Collapses to header only (session stays alive)
- **Expand** (maximize icon) - Toggles between normal (380px) and expanded (620px) height
- **Close** (X icon) - Closes terminal and kills PowerShell session

### Status Indicator
The colored dot in the header shows connection status:
- **Gray** - Disconnected
- **Yellow (pulsing)** - Connecting
- **Green** - Ready (PowerShell running)
- **Red** - Error

### Context Injection
When you enter a domain name or server IP in the left panel, the terminal automatically injects these as PowerShell variables:

```powershell
$global:domain        # Your FQDN (e.g., "corp.domain.local")
$global:domainDN      # Distinguished Name (e.g., "DC=corp,DC=domain,DC=local")
$global:targetServer  # Server IP or hostname
```

**Example usage:**
```powershell
# Test LDAP connection
[ADSI]"LDAP://$targetServer/$domainDN"

# Query specific OU
Get-ADUser -Filter * -SearchBase "OU=Users,$domainDN" -Server $targetServer
```

### Quick Command Buttons
The toolbar shows dynamic commands based on your configuration:

#### Always Available
- **whoami** - Shows current user
- **hostname** - Shows computer name
- **ipconfig** - Network configuration
- **$PSVersionTable** - PowerShell version info

#### When Server IP is Set
- **ping [IP]** - ICMP connectivity test
- **LDAP :389** - Test LDAP port
- **LDAPS :636** - Test LDAPS port
- **GC :3268** - Test Global Catalog port
- **Kerberos :88** - Test Kerberos port
- **RootDSE** - Query RootDSE for naming context

#### When Domain is Set
- **DNS [domain]** - Resolve domain name
- **Find DC** - Locate domain controllers via SRV records
- **ping [domain]** - Ping domain

#### When Both Domain and IP are Set
- **⚡ Full AD Test** - Comprehensive connectivity test (ICMP, LDAP, LDAPS, Kerberos, RootDSE)

### Common Use Cases

#### 1. Verify AD Connectivity Before Scanning
```powershell
# Quick test
Test-NetConnection $targetServer -Port 389

# Full test (use the ⚡ Full AD Test button)
```

#### 2. Check Current Credentials
```powershell
whoami
whoami /groups
```

#### 3. Test LDAP Query
```powershell
# Query RootDSE
[ADSI]"LDAP://$targetServer/RootDSE" | Select *

# Test domain connection
[ADSI]"LDAP://$targetServer/$domainDN"
```

#### 4. Verify DNS Resolution
```powershell
Resolve-DnsName $domain
nslookup -type=SRV _ldap._tcp.$domain
```

#### 5. Check Network Connectivity
```powershell
Test-Connection $targetServer -Count 4
Test-NetConnection $targetServer -Port 389 -InformationLevel Detailed
```

#### 6. Import AD Module (if available)
```powershell
Import-Module ActiveDirectory
Get-ADDomain -Server $targetServer
Get-ADForest -Server $targetServer
```

### Tips & Tricks

1. **Command History**: Use ↑/↓ arrow keys to navigate command history
2. **Tab Completion**: PowerShell tab completion works normally
3. **Copy/Paste**: Right-click to paste, select text to copy
4. **Multi-line Commands**: Use backtick (`) for line continuation
5. **Keep Session Alive**: Minimize the drawer instead of closing to preserve your session
6. **Update Variables**: If you change domain/IP in the left panel, click "Inject Context" to update PS variables

### Session Limits
- Maximum 3 concurrent terminal sessions
- 30-minute idle timeout (no input)
- Sessions are cleaned up when you close the drawer or navigate away

### Troubleshooting

#### Terminal Won't Open
- Check that backend server is running on port 3001
- Look for "[Terminal] WebSocket server attached" in backend console
- Verify no firewall blocking WebSocket connections

#### PowerShell Not Found
- Ensure `powershell.exe` is in your system PATH
- On Windows, PowerShell should be available by default
- Error message will show: "Failed to start PowerShell: ..."

#### Connection Lost
- Click the **Reconnect** button to start a new session
- Check backend server logs for errors
- Verify WebSocket proxy in vite.config.js

#### Commands Not Executing
- Verify status indicator is green (ready)
- Check that PowerShell prompt is visible (PS C:\>)
- Try typing a simple command like `whoami` manually

### Integration with Scans

The terminal is completely independent from the scan execution:
- You can open the terminal while a scan is running
- Scans continue normally when terminal is open/closed
- Terminal sessions don't affect scan results
- Use terminal to verify connectivity BEFORE starting a scan

### Security Notes

- Terminal runs with the same privileges as the backend Node.js process
- Commands are executed on the server, not in your browser
- Command content is NOT logged (only session open/close timestamps)
- Sessions timeout after 30 minutes of inactivity
- Maximum 3 concurrent sessions to prevent resource exhaustion

## Example Workflow

1. **Enter domain and server IP** in the left panel
2. **Click "PS Terminal"** button to open terminal
3. **Wait for context injection** (banner with variables appears)
4. **Click "⚡ Full AD Test"** to verify connectivity
5. **Review test results** - all ports should be reachable
6. **Run additional diagnostic commands** as needed
7. **Minimize terminal** to keep session alive
8. **Configure and run your scan** in the main panel
9. **Restore terminal** if you need to run more commands
10. **Close terminal** when done

## Keyboard Shortcuts

While terminal has focus:
- **Ctrl+C** - Cancel current command
- **Ctrl+L** - Clear screen (or use Clear button)
- **↑/↓** - Command history
- **Tab** - Auto-completion
- **Ctrl+R** - Reverse search history (if supported)

## Advanced Usage

### Custom Scripts
You can paste and run multi-line scripts:

```powershell
$users = Get-ADUser -Filter * -Server $targetServer
foreach ($user in $users) {
    Write-Host "$($user.Name) - $($user.Enabled)" -ForegroundColor $(if($user.Enabled){"Green"}else{"Red"})
}
```

### Variable Persistence
Variables you create persist for the session:

```powershell
$myDC = $targetServer
$myDomain = $domain
# These remain available until you close the terminal
```

### Error Handling
PowerShell errors appear in red in the terminal. Use try/catch for better error handling:

```powershell
try {
    [ADSI]"LDAP://$targetServer/$domainDN"
    Write-Host "Connection successful!" -ForegroundColor Green
} catch {
    Write-Host "Connection failed: $_" -ForegroundColor Red
}
```

---

**Need Help?** Check the backend console logs for detailed error messages and WebSocket connection status.
