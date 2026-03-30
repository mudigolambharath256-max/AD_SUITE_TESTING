import { useState, useEffect } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useSettings } from '../contexts/SettingsContext';
import api from '../lib/api';
import { getBackendOrigin } from '../lib/download';
import { 
    Terminal, Settings as SettingsIcon, Database, Eye, 
    Play, Save, CheckCircle2, XCircle, Activity,
    Trash2, Laptop
} from 'lucide-react';

interface AppSettings {
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

export default function Settings() {
    const queryClient = useQueryClient();
    const { tableDensity, setTableDensity, terminalFontSize, setTerminalFontSize } = useSettings();
    const [localConfig, setLocalConfig] = useState<AppSettings | null>(null);

    // Queries
    const { data: config, isLoading } = useQuery({
        queryKey: ['settings'],
        queryFn: async () => (await api.get('/settings')).data as AppSettings,
    });

    const { data: dbSize } = useQuery({
        queryKey: ['db-size'],
        queryFn: async () => (await api.get('/settings/database/size')).data.sizeBytes as number,
    });

    const { data: health } = useQuery({
        queryKey: ['health', getBackendOrigin()],
        queryFn: async () => {
            const r = await fetch(`${getBackendOrigin()}/health`);
            if (!r.ok) throw new Error('Health check failed');
            return r.json() as Promise<{ status?: string; version?: string }>;
        },
        refetchInterval: 10000
    });

    useEffect(() => {
        if (config) setLocalConfig(JSON.parse(JSON.stringify(config))); // Deep copy
    }, [config]);

    // Mutations
    const saveMutation = useMutation({
        mutationFn: async (newConfig: AppSettings) => await api.put('/settings', newConfig),
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['settings'] });
            alert('Settings saved successfully!');
        },
        onError: () => alert('Failed to save settings'),
    });

    const testPsMutation = useMutation({
        mutationFn: async () => (await api.post('/settings/test-powershell')).data,
    });

    const cleanupMutation = useMutation({
        mutationFn: async () => (await api.post('/settings/database/cleanup')).data,
        onSuccess: (data) => alert(data.message),
    });

    const handleSave = () => {
        if (localConfig) saveMutation.mutate(localConfig);
    };

    const detectCscPath = () => {
        if (!localConfig) return;
        setLocalConfig({
            ...localConfig,
            csharp: {
                ...localConfig.csharp,
                compilerPath: 'C:\\Windows\\Microsoft.NET\\Framework64\\v4.0.30319\\csc.exe'
            }
        });
    };

    if (isLoading || !localConfig) return <div className="p-8 text-text-secondary">Loading settings...</div>;

    const formatBytes = (b: number) => {
        if (b < 1024) return b + ' B';
        if (b < 1024 * 1024) return (b / 1024).toFixed(1) + ' KB';
        return (b / (1024 * 1024)).toFixed(1) + ' MB';
    };

    return (
        <div className="max-w-5xl mx-auto space-y-8 pb-12">
            <div className="flex items-center justify-between">
                <div>
                    <h1 className="text-3xl font-semibold text-text-primary mb-2 flex items-center gap-3">
                        <SettingsIcon className="text-accent-orange" size={28} /> Settings
                    </h1>
                    <p className="text-text-secondary">Manage application configuration and integrations.</p>
                </div>
                <button 
                    onClick={handleSave}
                    disabled={saveMutation.isPending}
                    className="flex items-center gap-2 bg-accent-orange hover:bg-accent-orange-hover text-white px-5 py-2.5 rounded-lg font-medium transition-colors"
                >
                    <Save size={18} /> {saveMutation.isPending ? 'Saving...' : 'Save Settings'}
                </button>
            </div>

            {/* System Information */}
            <section className="bg-surface-elevated border border-border-light rounded-xl p-6">
                <h2 className="text-xl font-semibold text-text-primary mb-4 flex items-center gap-2">
                    <Activity size={20} className="text-text-secondary" /> System Information
                </h2>
                <div className="grid grid-cols-2 gap-4">
                    <div className="p-4 bg-bg-tertiary rounded-lg border border-border-medium">
                        <div className="text-sm text-text-secondary mb-1">Backend Health</div>
                        <div className="flex items-center gap-2 font-medium">
                            {health ? (
                                <><div className="w-2.5 h-2.5 rounded-full bg-green-500 animate-pulse" /> {(health.status ?? 'ok').toUpperCase()}</>
                            ) : (
                                <><div className="w-2.5 h-2.5 rounded-full bg-critical" /> UNREACHABLE</>
                            )}
                        </div>
                    </div>
                    <div className="p-4 bg-bg-tertiary rounded-lg border border-border-medium">
                        <div className="text-sm text-text-secondary mb-1">Version Information</div>
                        <div className="font-mono text-text-primary">
                            Frontend: 1.0.0<br/>
                            Backend: {health?.version || 'Unknown'}
                        </div>
                    </div>
                </div>
            </section>

            {/* PowerShell Settings */}
            <section className="bg-surface-elevated border border-border-light rounded-xl p-6">
                <h2 className="text-xl font-semibold text-text-primary mb-4 flex items-center gap-2">
                    <Terminal size={20} className="text-text-secondary" /> PowerShell Settings
                </h2>
                <div className="space-y-5">
                    <div>
                        <label className="block text-sm font-medium text-text-secondary mb-2">Execution Policy</label>
                        <select 
                            className="w-full max-w-xs bg-bg-tertiary border border-border-medium rounded-lg px-4 py-2.5 text-text-primary focus:outline-none focus:border-accent-orange"
                            value={localConfig.powershell.executionPolicy}
                            onChange={e => setLocalConfig({...localConfig, powershell: {...localConfig.powershell, executionPolicy: e.target.value as any}})}
                        >
                            <option value="Bypass">Bypass</option>
                            <option value="Restricted">Restricted</option>
                            <option value="AllSigned">AllSigned</option>
                        </select>
                    </div>
                    
                    <div>
                        <label className="block text-sm font-medium text-text-secondary mb-2">Extra Flags</label>
                        <div className="space-y-3">
                            <label className="flex items-center gap-3 cursor-pointer group">
                                <input type="checkbox" className="w-4 h-4 rounded border-border-medium text-accent-orange focus:ring-accent-orange bg-bg-tertiary" 
                                    checked={localConfig.powershell.nonInteractive} 
                                    onChange={e => setLocalConfig({...localConfig, powershell: {...localConfig.powershell, nonInteractive: e.target.checked}})} 
                                />
                                <span className="text-text-primary group-hover:text-accent-orange transition-colors">NonInteractive (Suppress prompts)</span>
                            </label>
                            <label className="flex items-center gap-3 cursor-pointer group">
                                <input type="checkbox" className="w-4 h-4 rounded border-border-medium text-accent-orange focus:ring-accent-orange bg-bg-tertiary" 
                                    checked={localConfig.powershell.noProfile} 
                                    onChange={e => setLocalConfig({...localConfig, powershell: {...localConfig.powershell, noProfile: e.target.checked}})} 
                                />
                                <span className="text-text-primary group-hover:text-accent-orange transition-colors">NoProfile (Skip profile loading)</span>
                            </label>
                            <label className="flex items-center gap-3 cursor-pointer group">
                                <input type="checkbox" className="w-4 h-4 rounded border-border-medium text-accent-orange focus:ring-accent-orange bg-bg-tertiary" 
                                    checked={localConfig.powershell.windowStyleHidden} 
                                    onChange={e => setLocalConfig({...localConfig, powershell: {...localConfig.powershell, windowStyleHidden: e.target.checked}})} 
                                />
                                <span className="text-text-primary group-hover:text-accent-orange transition-colors">WindowStyle Hidden (Background execution)</span>
                            </label>
                        </div>
                    </div>

                    <div className="pt-4 border-t border-border-light">
                        <button 
                            onClick={() => testPsMutation.mutate()}
                            disabled={testPsMutation.isPending}
                            className="flex items-center gap-2 bg-bg-tertiary border border-border-medium hover:bg-bg-hover text-text-primary px-4 py-2 rounded-lg text-sm font-medium transition-colors mb-3"
                        >
                            <Play size={16} className="text-accent-orange" /> Default PowerShell Testing
                        </button>
                        
                        {testPsMutation.data && (
                            <div className={`p-4 rounded-lg flex items-start gap-3 ${testPsMutation.data.success ? 'bg-green-500/10 border border-green-500/20' : 'bg-critical/10 border border-critical/20'}`}>
                                {testPsMutation.data.success ? <CheckCircle2 className="text-green-500 mt-0.5" size={18} /> : <XCircle className="text-critical mt-0.5" size={18} />}
                                <div className="font-mono text-sm text-text-secondary whitespace-pre-wrap">{testPsMutation.data.output}</div>
                            </div>
                        )}
                    </div>
                </div>
            </section>

            {/* C# Compiler Settings */}
            <section className="bg-surface-elevated border border-border-light rounded-xl p-6">
                <h2 className="text-xl font-semibold text-text-primary mb-4 flex items-center gap-2">
                    <Laptop size={20} className="text-text-secondary" /> C# Compiler Settings
                </h2>
                <div className="space-y-5">
                    <div>
                        <label className="flex justify-between text-sm font-medium text-text-secondary mb-2">
                            Compiler Path (csc.exe)
                            <button onClick={detectCscPath} className="text-accent-orange hover:underline">Auto-detect</button>
                        </label>
                        <input 
                            className="w-full bg-bg-tertiary border border-border-medium rounded-lg px-4 py-2.5 text-text-primary focus:outline-none focus:border-accent-orange font-mono text-sm"
                            value={localConfig.csharp.compilerPath}
                            onChange={e => setLocalConfig({...localConfig, csharp: {...localConfig.csharp, compilerPath: e.target.value}})}
                        />
                    </div>
                    <div>
                        <label className="block text-sm font-medium text-text-secondary mb-2">.NET Framework Path</label>
                        <input 
                            className="w-full bg-bg-tertiary border border-border-medium rounded-lg px-4 py-2.5 text-text-primary focus:outline-none focus:border-accent-orange font-mono text-sm"
                            value={localConfig.csharp.dotNetFrameworkPath}
                            onChange={e => setLocalConfig({...localConfig, csharp: {...localConfig.csharp, dotNetFrameworkPath: e.target.value}})}
                        />
                    </div>
                </div>
            </section>

            {/* Database Settings */}
            <section className="bg-surface-elevated border border-border-light rounded-xl p-6">
                <h2 className="text-xl font-semibold text-text-primary mb-4 flex items-center gap-2">
                    <Database size={20} className="text-text-secondary" /> Database Settings
                </h2>
                <div className="space-y-5">
                    <div className="flex justify-between items-center p-4 bg-bg-tertiary rounded-lg border border-border-medium">
                        <div>
                            <div className="font-medium text-text-primary">Current Database Size</div>
                            <div className="text-sm text-text-secondary">Measured from internal SQLite storage</div>
                        </div>
                        <div className="text-xl font-mono text-text-primary font-semibold">{dbSize != null ? formatBytes(dbSize) : 'Loading...'}</div>
                    </div>

                    <div>
                        <label className="block text-sm font-medium text-text-secondary mb-2">History Retention Period (Days)</label>
                        <input 
                            type="number" min="1" max="365"
                            className="w-full max-w-xs bg-bg-tertiary border border-border-medium rounded-lg px-4 py-2.5 text-text-primary focus:outline-none focus:border-accent-orange"
                            value={localConfig.database.retentionDays}
                            onChange={e => setLocalConfig({...localConfig, database: {...localConfig.database, retentionDays: parseInt(e.target.value, 10) || 30}})}
                        />
                        <p className="mt-2 text-xs text-text-tertiary">Scan histories older than this will be automatically deleted.</p>
                    </div>

                    <div className="pt-4 border-t border-border-light">
                        <button 
                            onClick={() => {
                                if (confirm(`Are you sure you want to delete all records older than ${localConfig.database.retentionDays} days?`)) {
                                    cleanupMutation.mutate();
                                }
                            }}
                            className="flex items-center gap-2 bg-critical/10 border border-critical/30 hover:bg-critical/20 text-critical px-4 py-2 rounded-lg text-sm font-medium transition-colors"
                        >
                            <Trash2 size={16} /> Clear old history now
                        </button>
                    </div>
                </div>
            </section>

            {/* Appearance Settings */}
            <section className="bg-surface-elevated border border-border-light rounded-xl p-6">
                <h2 className="text-xl font-semibold text-text-primary mb-4 flex items-center gap-2">
                    <Eye size={20} className="text-text-secondary" /> Appearance Settings
                </h2>
                <div className="space-y-6">
                    <div>
                        <label className="block text-sm font-medium text-text-secondary mb-3">Table Density</label>
                        <div className="flex bg-bg-tertiary p-1 rounded-lg border border-border-medium w-fit">
                            {(['comfortable', 'compact', 'spacious'] as const).map(density => (
                                <button
                                    key={density}
                                    onClick={() => setTableDensity(density)}
                                    className={`px-4 py-2 rounded-md text-sm font-medium capitalize transition-colors ${tableDensity === density ? 'bg-surface-elevated text-accent-orange shadow-sm' : 'text-text-secondary hover:text-text-primary'}`}
                                >
                                    {density}
                                </button>
                            ))}
                        </div>
                    </div>

                    <div>
                        <label className="block text-sm font-medium text-text-secondary mb-3">
                            Terminal Font Size: <span className="text-text-primary font-mono">{terminalFontSize}px</span>
                        </label>
                        <input 
                            type="range" min="10" max="16" step="1"
                            value={terminalFontSize}
                            onChange={(e) => setTerminalFontSize(parseInt(e.target.value, 10))}
                            className="w-full max-w-sm accent-accent-orange"
                        />
                        <div 
                            className="mt-4 bg-gray-900 border border-gray-700 rounded-lg p-4 font-mono text-green-400 max-w-lg"
                            style={{ fontSize: `${terminalFontSize}px` }}
                        >
                            <div className="text-gray-500 mb-2"># Terminal Preview</div>
                            &gt; Invoke-ADSuiteScan -Category "ADCS"<br/>
                            [*] Starting Active Directory configuration scan...<br/>
                            [*] Found 3 findings matching the criteria.
                        </div>
                    </div>
                </div>
            </section>

        </div>
    );
}
