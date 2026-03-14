const { spawn } = require('child_process');

console.log('Testing PowerShell execution...');

const proc = spawn('powershell.exe', [
    '-ExecutionPolicy', 'Bypass',
    '-NonInteractive',
    '-NoProfile',
    '-Command', 'Write-Output "Hello from PowerShell"; Write-Output "Current directory: $(Get-Location)"; Write-Output "PowerShell version: $($PSVersionTable.PSVersion)"'
], { shell: false });

proc.stdout.on('data', (data) => {
    console.log('STDOUT:', data.toString());
});

proc.stderr.on('data', (data) => {
    console.error('STDERR:', data.toString());
});

proc.on('close', (code) => {
    console.log('Process exited with code:', code);
});

proc.on('error', (err) => {
    console.error('Process error:', err);
});
