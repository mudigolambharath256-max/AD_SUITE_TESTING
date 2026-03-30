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
export declare class SettingsService {
    initialize(): Promise<void>;
    getSettings(): Promise<AppSettings>;
    saveSettings(settings: Partial<AppSettings>): Promise<AppSettings>;
}
export declare const settingsService: SettingsService;
//# sourceMappingURL=settingsService.d.ts.map