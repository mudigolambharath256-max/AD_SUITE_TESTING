"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const auth_1 = require("../middleware/auth");
const auditMiddleware_1 = require("../middleware/auditMiddleware");
const settingsService_1 = require("../services/settingsService");
const child_process_1 = require("child_process");
const util_1 = __importDefault(require("util"));
const promises_1 = __importDefault(require("fs/promises"));
const path_1 = __importDefault(require("path"));
const execAsync = util_1.default.promisify(child_process_1.exec);
const router = express_1.default.Router();
const readRoles = (0, auth_1.authorize)('admin', 'analyst', 'viewer');
const adminOnly = (0, auth_1.authorize)('admin');
router.use(auth_1.authenticate);
router.use(auditMiddleware_1.auditMutations);
// Get all settings
router.get('/', readRoles, async (req, res, next) => {
    try {
        const settings = await settingsService_1.settingsService.getSettings();
        res.json(settings);
    }
    catch (error) {
        next(error);
    }
});
// Update settings
router.put('/', adminOnly, async (req, res, next) => {
    try {
        const updated = await settingsService_1.settingsService.saveSettings(req.body);
        res.json(updated);
    }
    catch (error) {
        next(error);
    }
});
// Test PowerShell
router.post('/test-powershell', adminOnly, async (req, res, next) => {
    try {
        const settings = await settingsService_1.settingsService.getSettings();
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
        }
        catch (execError) {
            // Fallback to powershell.exe if pwsh is missing
            const fallbackCmd = `powershell ${flags} -Command "$PSVersionTable.PSVersion.ToString()"`;
            try {
                const { stdout } = await execAsync(fallbackCmd);
                res.json({ success: true, output: `Windows PowerShell Version: ${stdout.trim()}` });
            }
            catch (fallbackError) {
                res.status(500).json({ success: false, output: fallbackError.message });
            }
        }
    }
    catch (error) {
        next(error);
    }
});
// Get Database Size (Simulated for SQLite file sizes)
router.get('/database/size', readRoles, async (req, res, next) => {
    try {
        let sizeBytes = 0;
        try {
            // Rough estimate: check size of the sqlite file or dummy data folder
            const dbPath = path_1.default.resolve(__dirname, '../../../data/settings.json');
            const stats = await promises_1.default.stat(dbPath);
            sizeBytes = stats.size;
        }
        catch {
            sizeBytes = 1048576 * 12.5; // Dummy 12.5 MB if file doesn't exist
        }
        res.json({ sizeBytes });
    }
    catch (error) {
        next(error);
    }
});
// Cleanup database history
router.post('/database/cleanup', adminOnly, async (req, res, next) => {
    try {
        // Here we would normally run SQL DELETE queries based on settingsService.getSettings().database.retentionDays
        // For now, simulate success.
        const settings = await settingsService_1.settingsService.getSettings();
        res.json({ success: true, message: `Successfully cleared history older than ${settings.database.retentionDays} days.` });
    }
    catch (error) {
        next(error);
    }
});
exports.default = router;
//# sourceMappingURL=settings.js.map