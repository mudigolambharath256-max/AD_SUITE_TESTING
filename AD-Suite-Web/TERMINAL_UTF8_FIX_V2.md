# Terminal UTF-8 Fix - Version 2

## The Issue
PowerShell terminal showing extra spaces: `P S  C : \ U s e r s \`

## Root Cause
- PowerShell uses UTF-16 encoding by default
- Frontend xterm.js expects UTF-8
- UTF-16 null bytes rendered as spaces

## First Attempt (FAILED)
Used `-Command` parameter to set UTF-8 encoding at startup.
**Problem**: PowerShell exited immediately after running the command.
**Result**: "[Process exited with code 0]"

## Second Attempt (CORRECT)
Inject UTF-8 commands AFTER PowerShell starts using `ptyProcess.write()`.

### Implementation
```typescript
// Spawn PowerShell normally (stays interactive)
const ptyProcess = pty.spawn('powershell.exe', [
    '-ExecutionPolicy', 'Bypass',
    '-NoProfile',
    '-NoLogo'
], { /* options */ });

// Inject UTF-8 commands after 500ms delay
setTimeout(() => {
    ptyProcess.write('[Console]::OutputEncoding = [System.Text.Encoding]::UTF8\r');
    ptyProcess.write('[Console]::InputEncoding = [System.Text.Encoding]::UTF8\r');
    ptyProcess.write('$OutputEncoding = [System.Text.Encoding]::UTF8\r');
    ptyProcess.write('chcp 65001 > $null\r');
    ptyProcess.write('Clear-Host\r');
}, 500);
```

## Why This Works
1. PowerShell starts in interactive mode (doesn't exit)
2. 500ms delay ensures PowerShell is ready
3. Commands are injected as if typed by user
4. `chcp 65001` sets Windows console to UTF-8
5. `Clear-Host` cleans up the screen

## Testing
1. Hard refresh browser: `Ctrl + Shift + R`
2. Navigate to: http://localhost:5173/terminal
3. Click "Connect to PowerShell"
4. Should see: `PS C:\Users\acer>` (no extra spaces)
5. Test command: `Get-Date`

## Status
✅ Backend restarted automatically
✅ Fix applied
✅ Ready to test

---
**Version**: 1.0.2
**Date**: March 29, 2026
