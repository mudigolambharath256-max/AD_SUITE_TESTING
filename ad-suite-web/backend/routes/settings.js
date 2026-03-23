const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const db = require('../services/db');

// Get suite information by scanning the directory
router.get('/suite-info', (req, res) => {
    try {
        const suiteRoot = req.query.path;

        if (!suiteRoot || !fs.existsSync(suiteRoot)) {
            return res.json({ valid: false, error: 'Path not found or invalid' });
        }

        const result = scanSuiteRoot(suiteRoot);
        res.json(result);
    } catch (error) {
        console.error('Error scanning suite root:', error);
        res.status(500).json({ valid: false, error: error.message });
    }
});

// Detect csc.exe location
router.post('/detect-csc', async (req, res) => {
    try {
        const candidates = [
            'C:\\Windows\\Microsoft.NET\\Framework64\\v4.0.30319\\csc.exe',
            'C:\\Windows\\Microsoft.NET\\Framework\\v4.0.30319\\csc.exe',
            'C:\\Windows\\Microsoft.NET\\Framework64\\v4.5.50709\\csc.exe',
            'C:\\Windows\\Microsoft.NET\\Framework64\\v3.5\\csc.exe',
        ];

        // Check known paths first
        for (const p of candidates) {
            if (fs.existsSync(p)) {
                return res.json({ found: true, path: p });
            }
        }

        // Try using where.exe
        const whereResult = await new Promise((resolve) => {
            const proc = spawn('where.exe', ['csc'], { shell: false });
            let stdout = '';
            proc.stdout.on('data', (d) => { stdout += d.toString(); });
            proc.on('close', (code) => {
                if (code === 0 && stdout.trim()) {
                    const firstPath = stdout.trim().split('\n')[0].trim();
                    resolve(firstPath);
                } else {
                    resolve(null);
                }
            });
            proc.on('error', () => resolve(null));
        });

        if (whereResult) {
            return res.json({ found: true, path: whereResult });
        }

        res.json({ found: false, path: null });
    } catch (error) {
        console.error('Error detecting csc:', error);
        res.json({ found: false, path: null, error: error.message });
    }
});

// Test PowerShell execution policy
router.post('/test-execution-policy', async (req, res) => {
    try {
        const result = await new Promise((resolve) => {
            const proc = spawn('powershell.exe', [
                '-ExecutionPolicy', 'Bypass',
                '-NonInteractive',
                '-NoProfile',
                '-Command', 'Write-Output "OK"'
            ], { shell: false, timeout: 5000 });

            let stdout = '';
            let stderr = '';

            proc.stdout.on('data', (d) => { stdout += d.toString(); });
            proc.stderr.on('data', (d) => { stderr += d.toString(); });

            proc.on('close', (code) => {
                if (code === 0 && stdout.includes('OK')) {
                    resolve({ ok: true });
                } else {
                    resolve({ ok: false, error: stderr || 'PowerShell test failed' });
                }
            });

            proc.on('error', (err) => {
                resolve({ ok: false, error: err.message });
            });
        });

        res.json(result);
    } catch (error) {
        console.error('Error testing execution policy:', error);
        res.json({ ok: false, error: error.message });
    }
});

// Export database
router.post('/export-db', (req, res) => {
    try {
        const dbPath = db.getDbPath();

        if (!fs.existsSync(dbPath)) {
            return res.status(404).json({ error: 'Database file not found' });
        }

        res.setHeader('Content-Disposition', `attachment; filename="ad-suite-${Date.now()}.db"`);
        res.setHeader('Content-Type', 'application/octet-stream');

        fs.createReadStream(dbPath).pipe(res);
    } catch (error) {
        console.error('Error exporting database:', error);
        res.status(500).json({ error: error.message });
    }
});

// Clear scan history
router.post('/clear-history', (req, res) => {
    try {
        db.clearHistory();
        res.json({ success: true, message: 'Scan history cleared' });
    } catch (error) {
        console.error('Error clearing history:', error);
        res.status(500).json({ error: error.message });
    }
});

// Reset database
router.post('/reset-db', (req, res) => {
    try {
        db.resetDatabase();
        res.json({ success: true, message: 'Database reset successfully' });
    } catch (error) {
        console.error('Error resetting database:', error);
        res.status(500).json({ error: error.message });
    }
});

// Save setting
router.post('/save', (req, res) => {
    try {
        const { key, value } = req.body;

        if (!key) {
            return res.status(400).json({ error: 'Key is required' });
        }

        db.setSetting(key, value);
        res.json({ saved: true });
    } catch (error) {
        console.error('Error saving setting:', error);
        res.status(500).json({ error: error.message });
    }
});

// Browse folders - Native Windows dialog
router.post('/browse-folder-native', (req, res) => {
    try {
        const { spawn } = require('child_process');

        // Use PowerShell to show folder browser dialog with STA mode
        const psScript = `
[void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
$folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
$folderBrowser.Description = 'Select AD Suite Root Folder'
$folderBrowser.ShowNewFolderButton = $false
$folderBrowser.RootFolder = [System.Environment+SpecialFolder]::MyComputer
$result = $folderBrowser.ShowDialog()
if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
    Write-Output $folderBrowser.SelectedPath
} else {
    Write-Output 'CANCELLED'
}
        `.trim();

        const ps = spawn('powershell.exe', [
            '-NoProfile',
            '-NonInteractive',
            '-Sta',  // Single-Threaded Apartment mode required for Windows Forms
            '-Command',
            psScript
        ]);

        let output = '';
        let error = '';

        ps.stdout.on('data', (data) => {
            output += data.toString();
        });

        ps.stderr.on('data', (data) => {
            error += data.toString();
        });

        ps.on('close', (code) => {
            const trimmedOutput = output.trim();

            if (trimmedOutput === 'CANCELLED') {
                return res.json({
                    success: false,
                    cancelled: true
                });
            }

            if (code === 0 && trimmedOutput && trimmedOutput !== 'CANCELLED') {
                return res.json({
                    success: true,
                    path: trimmedOutput
                });
            }

            console.error('Folder browser error:', error);
            res.json({
                success: false,
                error: error || 'Unknown error',
                cancelled: false
            });
        });

        ps.on('error', (err) => {
            console.error('PowerShell spawn error:', err);
            res.json({
                success: false,
                error: err.message
            });
        });

        // Timeout after 2 minutes (user might take time to browse)
        setTimeout(() => {
            try {
                ps.kill();
            } catch (e) {
                // Process might already be closed
            }
            if (!res.headersSent) {
                res.json({
                    success: false,
                    error: 'Dialog timeout',
                    cancelled: true
                });
            }
        }, 120000);

    } catch (error) {
        console.error('Error showing folder dialog:', error);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// Browse folders
router.post('/browse-folder', (req, res) => {
    try {
        let { path = 'drives' } = req.body;

        // Special case: list drives on Windows
        if (path === 'drives' || path === '' || path === '.') {
            const drives = [];
            // Check common drive letters on Windows
            for (let i = 65; i <= 90; i++) { // A-Z
                const driveLetter = String.fromCharCode(i);
                const drivePath = `${driveLetter}:\\`;
                try {
                    if (fs.existsSync(drivePath)) {
                        drives.push({
                            name: `${driveLetter}:`,
                            path: drivePath,
                            isDirectory: true,
                            isDrive: true,
                            size: 0,
                            modified: new Date()
                        });
                    }
                } catch (err) {
                    // Skip inaccessible drives
                }
            }

            return res.json({
                currentPath: 'This PC',
                parentPath: null,
                items: drives,
                isDriveList: true
            });
        }

        if (!fs.existsSync(path)) {
            return res.json({ error: 'Path does not exist' });
        }

        const stats = fs.statSync(path);
        if (!stats.isDirectory()) {
            return res.json({ error: 'Path is not a directory' });
        }

        let items = [];
        let parentPath = null;

        try {
            items = fs.readdirSync(path).map(item => {
                const itemPath = require('path').join(path, item);
                try {
                    const itemStats = fs.statSync(itemPath);
                    return {
                        name: item,
                        path: itemPath,
                        isDirectory: itemStats.isDirectory(),
                        size: itemStats.size,
                        modified: itemStats.mtime
                    };
                } catch (err) {
                    // Skip inaccessible items
                    return null;
                }
            }).filter(item => item !== null);

            // Sort: directories first, then files, alphabetically
            items.sort((a, b) => {
                if (a.isDirectory !== b.isDirectory) {
                    return a.isDirectory ? -1 : 1;
                }
                return a.name.toLowerCase().localeCompare(b.name.toLowerCase());
            });

            // Determine parent path
            const resolvedPath = require('path').resolve(path);
            const parentResolved = require('path').resolve(path, '..');

            // Check if we're at a drive root (e.g., C:\)
            if (resolvedPath !== parentResolved) {
                parentPath = parentResolved;
            } else {
                // At drive root, go back to drive list
                parentPath = 'drives';
            }

        } catch (err) {
            console.error('Error reading directory:', err);
            return res.json({ error: 'Cannot read directory contents' });
        }

        res.json({
            currentPath: path,
            parentPath,
            items
        });
    } catch (error) {
        console.error('Error browsing folder:', error);
        res.status(500).json({ error: error.message });
    }
});

// Get setting
router.get('/:key', (req, res) => {
    try {
        const { key } = req.params;
        const value = db.getSetting(key);

        res.json({ value: value || null });
    } catch (error) {
        console.error('Error getting setting:', error);
        res.status(500).json({ error: error.message });
    }
});

// Helper function to scan suite root
function scanSuiteRoot(suiteRoot) {
    const engines = { adsi: 0, powershell: 0, csharp: 0, cmd: 0, combined: 0 };
    const engineFiles = {
        adsi: 'adsi.ps1',
        powershell: 'powershell.ps1',
        csharp: 'csharp.cs',
        cmd: 'cmd.bat',
        combined: 'combined_multiengine.ps1'
    };
    const categoryList = [];
    let totalChecks = 0;

    const categories = fs.readdirSync(suiteRoot);

    for (const cat of categories) {
        const catPath = path.join(suiteRoot, cat);

        if (!fs.statSync(catPath).isDirectory()) continue;

        let catCheckCount = 0;
        const checkFolders = fs.readdirSync(catPath);

        for (const checkFolder of checkFolders) {
            const checkPath = path.join(catPath, checkFolder);

            if (!fs.statSync(checkPath).isDirectory()) continue;

            // Check direct scripts or nested
            const pathsToCheck = [checkPath];

            try {
                const subItems = fs.readdirSync(checkPath);
                for (const sub of subItems) {
                    const subPath = path.join(checkPath, sub);
                    if (fs.statSync(subPath).isDirectory()) {
                        pathsToCheck.push(subPath);
                    }
                }
            } catch (err) {
                // Skip if can't read subdirectories
            }

            let foundScript = false;
            for (const p of pathsToCheck) {
                try {
                    const files = fs.readdirSync(p);

                    if (files.some(f => f.endsWith('.ps1') || f.endsWith('.cs') || f.endsWith('.bat'))) {
                        if (!foundScript) {
                            catCheckCount++;
                            foundScript = true;
                        }

                        for (const [key, file] of Object.entries(engineFiles)) {
                            if (files.includes(file)) {
                                engines[key]++;
                            }
                        }
                    }
                } catch (err) {
                    // Skip if can't read directory
                }
            }
        }

        if (catCheckCount > 0) {
            categoryList.push({ name: cat, checkCount: catCheckCount });
            totalChecks += catCheckCount;
        }
    }

    return {
        valid: true,
        categories: categoryList.length,
        checks: totalChecks,
        engines,
        categoryList
    };
}

module.exports = router;
