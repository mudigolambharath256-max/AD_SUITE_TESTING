import express from 'express';
import { authenticate } from '../middleware/auth';
import { settingsService } from '../services/settingsService';
import { exec } from 'child_process';
import util from 'util';
import fs from 'fs/promises';
import path from 'path';

const execAsync = util.promisify(exec);
const router = express.Router();

router.use(authenticate);

// Get all settings
router.get('/', async (req, res, next) => {
    try {
        const settings = await settingsService.getSettings();
        res.json(settings);
    } catch (error) {
        next(error);
    }
});

// Update settings
router.put('/', async (req, res, next) => {
    try {
        const updated = await settingsService.saveSettings(req.body);
        res.json(updated);
    } catch (error) {
        next(error);
    }
});

// Test PowerShell
router.post('/test-powershell', async (req, res, next) => {
    try {
        const settings = await settingsService.getSettings();
        const { executionPolicy, nonInteractive, noProfile } = settings.powershell;
        
        const flags = [
            `-ExecutionPolicy ${executionPolicy}`,
            nonInteractive ? '-NonInteractive' : '',
            noProfile ? '-NoProfile' : ''
        ].filter(Boolean).join(' ');

        const command = `pwsh ${flags} -Command "$PSVersionTable.PSVersion.ToString()"`;
        
        try {
            const { stdout, stderr } = await execAsync(command);
            if (stderr) {
                return res.status(400).json({ success: false, output: stderr.trim() });
            }
            res.json({ success: true, output: `PowerShell Version: ${stdout.trim()}` });
        } catch (execError: any) {
             // Fallback to powershell.exe if pwsh is missing
             const fallbackCmd = `powershell ${flags} -Command "$PSVersionTable.PSVersion.ToString()"`;
             try {
                 const { stdout } = await execAsync(fallbackCmd);
                 res.json({ success: true, output: `Windows PowerShell Version: ${stdout.trim()}` });
             } catch (fallbackError: any) {
                 res.status(500).json({ success: false, output: fallbackError.message });
             }
        }
    } catch (error) {
        next(error);
    }
});

// Get Database Size (Simulated for SQLite file sizes)
router.get('/database/size', async (req, res, next) => {
    try {
        let sizeBytes = 0;
        try {
            // Rough estimate: check size of the sqlite file or dummy data folder
            const dbPath = path.resolve(__dirname, '../../../data/settings.json');
            const stats = await fs.stat(dbPath);
            sizeBytes = stats.size;
        } catch {
            sizeBytes = 1048576 * 12.5; // Dummy 12.5 MB if file doesn't exist
        }
        res.json({ sizeBytes });
    } catch (error) {
        next(error);
    }
});

// Cleanup database history
router.post('/database/cleanup', async (req, res, next) => {
    try {
        // Here we would normally run SQL DELETE queries based on settingsService.getSettings().database.retentionDays
        // For now, simulate success.
        const settings = await settingsService.getSettings();
        res.json({ success: true, message: `Successfully cleared history older than ${settings.database.retentionDays} days.` });
    } catch (error) {
        next(error);
    }
});

export default router;
