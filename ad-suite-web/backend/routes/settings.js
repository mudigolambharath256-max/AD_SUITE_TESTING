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
