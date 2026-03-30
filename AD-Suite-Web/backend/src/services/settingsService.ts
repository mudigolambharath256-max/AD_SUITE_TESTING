import fs from 'fs/promises';
import path from 'path';

export interface AppSettings {
    powershell: {
        executionPolicy: 'Bypass' | 'Restricted' | 'AllSigned';
        nonInteractive: boolean;
        noProfile: boolean;
        windowStyleHidden: boolean;
    };
    csharp: {
        compilerPath: string;
        dotNetFrameworkPath: string;
    };
    database: {
        retentionDays: number;
    };
}

const DEFAULT_SETTINGS: AppSettings = {
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

const DATA_DIR = path.resolve(__dirname, '../../data');
const SETTINGS_FILE = path.join(DATA_DIR, 'settings.json');

export class SettingsService {
    async initialize() {
        try {
            await fs.mkdir(DATA_DIR, { recursive: true });
            // Check if file exists
            await fs.access(SETTINGS_FILE);
        } catch {
            // File doesn't exist, create default
            await this.saveSettings(DEFAULT_SETTINGS);
        }
    }

    async getSettings(): Promise<AppSettings> {
        try {
            const data = await fs.readFile(SETTINGS_FILE, 'utf-8');
            const parsed = JSON.parse(data);
            return { ...DEFAULT_SETTINGS, ...parsed };
        } catch (error) {
            console.error('Failed to read settings, using defaults', error);
            return DEFAULT_SETTINGS;
        }
    }

    async saveSettings(settings: Partial<AppSettings>): Promise<AppSettings> {
        const current = await this.getSettings();
        
        // Deep merge
        const updated = {
            powershell: { ...current.powershell, ...settings.powershell },
            csharp: { ...current.csharp, ...settings.csharp },
            database: { ...current.database, ...settings.database }
        };

        await fs.writeFile(SETTINGS_FILE, JSON.stringify(updated, null, 2));
        return updated;
    }
}

export const settingsService = new SettingsService();
