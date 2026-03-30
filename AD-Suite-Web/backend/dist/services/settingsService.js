"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.settingsService = exports.SettingsService = void 0;
const promises_1 = __importDefault(require("fs/promises"));
const path_1 = __importDefault(require("path"));
const DEFAULT_SETTINGS = {
    powershell: {
        executionPolicy: 'Bypass',
        nonInteractive: true,
        noProfile: true,
        windowStyleHidden: true
    },
    csharp: {
        compilerPath: 'C:\\Windows\\Microsoft.NET\\Framework64\\v4.0.30319\\csc.exe',
        dotNetFrameworkPath: 'C:\\Windows\\Microsoft.NET\\Framework64\\v4.0.30319'
    },
    database: {
        retentionDays: 30
    }
};
const DATA_DIR = path_1.default.resolve(__dirname, '../../data');
const SETTINGS_FILE = path_1.default.join(DATA_DIR, 'settings.json');
class SettingsService {
    async initialize() {
        try {
            await promises_1.default.mkdir(DATA_DIR, { recursive: true });
            // Check if file exists
            await promises_1.default.access(SETTINGS_FILE);
        }
        catch {
            // File doesn't exist, create default
            await this.saveSettings(DEFAULT_SETTINGS);
        }
    }
    async getSettings() {
        try {
            const data = await promises_1.default.readFile(SETTINGS_FILE, 'utf-8');
            const parsed = JSON.parse(data);
            return { ...DEFAULT_SETTINGS, ...parsed };
        }
        catch (error) {
            console.error('Failed to read settings, using defaults', error);
            return DEFAULT_SETTINGS;
        }
    }
    async saveSettings(settings) {
        const current = await this.getSettings();
        // Deep merge
        const updated = {
            powershell: { ...current.powershell, ...settings.powershell },
            csharp: { ...current.csharp, ...settings.csharp },
            database: { ...current.database, ...settings.database }
        };
        await promises_1.default.writeFile(SETTINGS_FILE, JSON.stringify(updated, null, 2));
        return updated;
    }
}
exports.SettingsService = SettingsService;
exports.settingsService = new SettingsService();
//# sourceMappingURL=settingsService.js.map