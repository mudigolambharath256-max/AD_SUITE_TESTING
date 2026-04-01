import { useState, useEffect, useMemo } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { useQuery, useMutation } from '@tanstack/react-query';
import { 
    Play, Search, CheckCircle2, XCircle, Loader2, 
    ChevronDown, ChevronRight, Trash2, Zap, 
    CheckSquare, Square, History, Activity
} from 'lucide-react';
import api from '../lib/api';
import GraphVisualizer from '../components/GraphVisualizer';
import clsx from 'clsx';

interface Check {
    id: string;
    name: string;
    category: string;
    severity: string;
    description: string;
    engine: string;
}

interface ScanProgress {
    status: string;
    message: string;
    progress: number;
    results?: any;
}

const severityColors: Record<string, string> = {
    critical: 'text-critical border-critical/30 bg-critical/5',
    high: 'text-high border-high/30 bg-high/5',
    medium: 'text-medium border-medium/30 bg-medium/5',
    low: 'text-low border-low/30 bg-low/5',
    info: 'text-info border-info/30 bg-info/5'
};

export default function NewScan() {
    const navigate = useNavigate();
    const [searchParams] = useSearchParams();
    const initialCategory = searchParams.get('category');

    const [scanName, setScanName] = useState('');
    const [selectedChecks, setSelectedChecks] = useState<Set<string>>(new Set());
    const [searchTerm, setSearchTerm] = useState('');
    const [expandedCategories, setExpandedCategories] = useState<Set<string>>(new Set());
    const [scanProgress, setScanProgress] = useState<ScanProgress | null>(null);
    const [scanResults, setScanResults] = useState<any>(null);

    // Fetch available checks and categories
    const { data: catalogData, isLoading: catalogLoading } = useQuery({
        queryKey: ['checks'],
        queryFn: async () => {
            const response = await api.get('/checks');
            return response.data;
        }
    });

    // Auto-select category if provided in URL
    useEffect(() => {
        if (initialCategory && catalogData?.checks) {
            const checksInCategory = catalogData.checks
                .filter((c: Check) => c.category === initialCategory)
                .map((c: Check) => c.id);
            
            if (checksInCategory.length > 0) {
                setSelectedChecks(new Set(checksInCategory));
                setExpandedCategories(new Set([initialCategory]));
                setScanName(`${initialCategory.replace(/_/g, ' ')} Audit`);
            }
        }
    }, [initialCategory, catalogData]);

    // Setup WebSocket connection (use server hostname when UI is opened via LAN IP / DNS name)
    useEffect(() => {
        const wsUrl =
            import.meta.env.VITE_WS_URL ||
            (() => {
                const p = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
                const port = import.meta.env.VITE_WS_PORT || '3001';
                return `${p}//${window.location.hostname}:${port}`;
            })();
        const websocket = new WebSocket(wsUrl);

        websocket.onmessage = (event) => {
            try {
                const data = JSON.parse(event.data);
                if (data.type === 'scan_update') {
                    setScanProgress(data.data);
                    if (data.data.status === 'completed' && data.data.results) {
                        setScanResults(data.data.results);
                    }
                }
            } catch (error) {
                console.error('WebSocket message error:', error);
            }
        };

        return () => websocket.close();
    }, []);

    const executeScanMutation = useMutation({
        mutationFn: async (scanData: any) => {
            return (await api.post(`/scans/${scanData.id}/execute`, {
                categories: scanData.categories,
                includeCheckIds: scanData.includeCheckIds
            })).data;
        },
        onError: () => {
            setScanProgress({ status: 'failed', message: 'Failed to start scan execution engine', progress: 0 });
        }
    });

    // Grouping and Filtering
    const groupedChecks = useMemo(() => {
        if (!catalogData?.checks) return {};
        const groups: Record<string, Check[]> = {};
        
        catalogData.checks.forEach((check: Check) => {
            const matchesSearch = searchTerm === '' ||
                check.id.toLowerCase().includes(searchTerm.toLowerCase()) ||
                check.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
                check.description.toLowerCase().includes(searchTerm.toLowerCase());

            if (matchesSearch) {
                if (!groups[check.category]) groups[check.category] = [];
                groups[check.category].push(check);
            }
        });
        return groups;
    }, [catalogData, searchTerm]);

    const categories = useMemo(() => Object.keys(groupedChecks).sort(), [groupedChecks]);

    // Selection Helpers
    const toggleCheck = (id: string) => {
        const next = new Set(selectedChecks);
        next.has(id) ? next.delete(id) : next.add(id);
        setSelectedChecks(next);
    };

    const toggleCategorySelection = (category: string) => {
        const checks = groupedChecks[category] || [];
        const next = new Set(selectedChecks);
        const allSelected = checks.every(c => next.has(c.id));
        
        if (allSelected) {
            checks.forEach(c => next.delete(c.id));
        } else {
            checks.forEach(c => next.add(c.id));
            // Also expand it if we're selecting it
            const nextExp = new Set(expandedCategories);
            nextExp.add(category);
            setExpandedCategories(nextExp);
        }
        setSelectedChecks(next);
    };

    const selectAll = () => {
        const allIds = catalogData?.checks.map((c: Check) => c.id) || [];
        setSelectedChecks(new Set(allIds));
    };

    const deselectAll = () => {
        setSelectedChecks(new Set());
    };

    const handleRunScan = async () => {
        if (selectedChecks.size === 0) return;
        
        const scanId = Date.now();
        const includeCheckIds = Array.from(selectedChecks);
        
        setScanProgress({ status: 'starting', message: 'Initializing Security Scan Environment...', progress: 0 });
        executeScanMutation.mutate({ id: scanId, includeCheckIds });
    };

    if (catalogLoading) {
        return (
            <div className="flex flex-col items-center justify-center h-96 space-y-4">
                <Loader2 className="w-10 h-10 animate-spin text-accent-orange" />
                <span className="text-text-secondary font-medium uppercase tracking-widest text-xs">Loading Security Catalog...</span>
            </div>
        );
    }

    return (
        <div className="max-w-6xl mx-auto pb-20">
            <div className="flex flex-col md:flex-row md:items-end justify-between gap-4 mb-8">
                <div>
                    <h1 className="text-3xl font-bold text-white tracking-tight mb-1">New Security Scan</h1>
                    <p className="text-text-secondary">Configure scope and targeted checks for AD assessment</p>
                </div>
                <div className="flex gap-3">
                    <button 
                        onClick={() => navigate('/reports')}
                        className="flex items-center gap-2 px-4 py-2 bg-bg-tertiary border border-border-medium rounded-xl text-text-secondary hover:text-white transition-all text-sm font-bold uppercase tracking-wider"
                    >
                        <History size={16} /> History
                    </button>
                    <button 
                        onClick={selectAll}
                        className="flex items-center gap-2 px-4 py-2 bg-accent-orange/10 border border-accent-orange/40 rounded-xl text-accent-orange hover:bg-accent-orange/20 transition-all text-sm font-bold uppercase tracking-wider"
                    >
                        <Zap size={16} /> Run Full Suite
                    </button>
                </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
                {/* Left: Configuration & Summary */}
                <div className="space-y-6">
                    <div className="bg-bg-tertiary border border-border-medium rounded-2xl p-6 shadow-xl">
                        <h2 className="text-[10px] font-bold text-white uppercase tracking-widest mb-6 border-b border-border-medium pb-2">Configuration</h2>
                        
                        <div className="space-y-4">
                            <div>
                                <label className="block text-[8px] font-bold text-text-tertiary uppercase tracking-widest mb-2">Scan Identity</label>
                                <input
                                    type="text"
                                    value={scanName}
                                    onChange={(e) => setScanName(e.target.value)}
                                    placeholder="e.g. Identity Baseline 2024"
                                    className="w-full px-4 py-3 bg-bg-secondary border border-border-medium rounded-xl text-white text-sm focus:outline-none focus:border-accent-orange/50 transition-all"
                                />
                            </div>

                            <div className="bg-white/5 rounded-xl p-4 border border-border-medium">
                                <div className="flex justify-between items-center mb-2">
                                    <span className="text-[8px] font-bold text-text-tertiary uppercase tracking-widest">Scope Summary</span>
                                    <span className="px-2 py-0.5 rounded-md bg-accent-orange/20 text-accent-orange text-[10px] font-bold uppercase">{selectedChecks.size} Targeted</span>
                                </div>
                                <div className="text-xs text-text-secondary leading-relaxed">
                                    {selectedChecks.size === 0 
                                        ? "No checks selected. Please choose from the catalog or run the full suite."
                                        : `Your scan target includes ${selectedChecks.size} security checks across ${new Set(Array.from(selectedChecks).map(id => catalogData?.checks.find((c: Check) => c.id === id)?.category)).size} categories.`
                                    }
                                </div>
                            </div>

                            <button
                                onClick={handleRunScan}
                                disabled={selectedChecks.size === 0 || scanProgress?.status === 'running'}
                                className={clsx(
                                    "w-full flex items-center justify-center gap-3 px-6 py-4 rounded-xl font-bold uppercase tracking-widest transition-all",
                                    (selectedChecks.size === 0 || scanProgress?.status === 'running')
                                        ? "bg-bg-secondary text-text-tertiary cursor-not-allowed border border-border-medium"
                                        : "bg-accent-orange hover:bg-accent-orange-hover text-white shadow-lg shadow-accent-orange/20"
                                )}
                            >
                                {scanProgress?.status === 'running' ? <Loader2 size={18} className="animate-spin" /> : <Play size={18} fill="currentColor" />}
                                {scanProgress?.status === 'running' ? 'Executing...' : 'Engage Scan'}
                            </button>
                            
                            {selectedChecks.size > 0 && (
                                <button 
                                    onClick={deselectAll}
                                    className="w-full py-3 text-[10px] font-bold uppercase tracking-widest text-text-tertiary hover:text-critical flex items-center justify-center gap-2 transition-all"
                                >
                                    <Trash2 size={14} /> Clear All Selections
                                </button>
                            )}
                        </div>
                    </div>

                    {scanProgress && (
                        <div className="bg-bg-tertiary border border-border-medium rounded-2xl p-6 shadow-xl animate-in zoom-in-95 duration-300">
                             <div className="flex items-center justify-between mb-4">
                                <h2 className="text-[10px] font-bold text-white uppercase tracking-widest">Active Progress</h2>
                                <span className={clsx(
                                    "text-[8px] font-bold px-2 py-0.5 rounded uppercase",
                                    scanProgress.status === 'completed' ? "bg-green-500/20 text-green-500" : "bg-accent-orange/20 text-accent-orange"
                                )}>{scanProgress.status}</span>
                            </div>
                            
                            <div className="relative pt-1">
                                <div className="flex mb-2 items-center justify-between">
                                    <div className="text-[10px] text-text-secondary truncate max-w-[80%] italic">{scanProgress.message}</div>
                                    <div className="text-right text-[10px] font-bold text-white">{scanProgress.progress}%</div>
                                </div>
                                <div className="overflow-hidden h-1 text-xs flex rounded bg-white/5">
                                    <div 
                                        style={{ width: `${scanProgress.progress}%` }} 
                                        className={clsx("shadow-none flex flex-col text-center whitespace-nowrap text-white justify-center transition-all duration-500", scanProgress.status === 'completed' ? "bg-green-500" : "bg-accent-orange")}
                                    />
                                </div>
                            </div>
                        </div>
                    )}
                </div>

                {/* Right: Catalog Selection */}
                <div className="lg:col-span-2 space-y-4">
                    <div className="bg-bg-tertiary border border-border-medium rounded-2xl p-6 shadow-xl min-h-[600px] flex flex-col">
                        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-6">
                            <h2 className="text-sm font-bold text-white uppercase tracking-widest">Check Selection Matrix</h2>
                            <div className="relative w-full md:w-64">
                                <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-text-tertiary" size={16} />
                                <input
                                    type="text"
                                    value={searchTerm}
                                    onChange={(e) => setSearchTerm(e.target.value)}
                                    placeholder="Filter catalog..."
                                    className="w-full pl-10 pr-4 py-2 bg-bg-secondary border border-border-medium rounded-xl text-xs text-white focus:outline-none focus:border-accent-orange/40 transition-all font-mono"
                                />
                            </div>
                        </div>

                        <div className="space-y-2 flex-grow overflow-y-auto pr-1 max-h-[70vh]">
                            {!catalogData?.checks || categories.length === 0 ? (
                                <div className="flex flex-col items-center justify-center p-20 text-center space-y-4 opacity-50">
                                    <XCircle size={48} className="text-text-tertiary" />
                                    <p className="text-sm text-text-tertiary tracking-wide uppercase font-bold">
                                        {!catalogData?.checks ? "Failed to load check catalog" : "No checks match your search filter"}
                                    </p>
                                </div>
                            ) : (
                                categories.map(cat => {
                                    const checks = groupedChecks[cat];
                                    const isExpanded = expandedCategories.has(cat);
                                    const selectedCount = checks.filter(c => selectedChecks.has(c.id)).length;
                                    const allSelected = selectedCount === checks.length;
                                    const someSelected = selectedCount > 0 && !allSelected;

                                    return (
                                        <div key={cat} className="group border border-border-medium rounded-xl overflow-hidden hover:border-accent-orange/20 transition-all">
                                            <div className="flex items-center px-4 py-3 bg-white/5 group-hover:bg-white/10 transition-colors cursor-pointer" onClick={() => {
                                                const next = new Set(expandedCategories);
                                                isExpanded ? next.delete(cat) : next.add(cat);
                                                setExpandedCategories(next);
                                            }}>
                                                <div className="mr-3" onClick={(e) => { e.stopPropagation(); toggleCategorySelection(cat); }}>
                                                    {allSelected ? <CheckSquare size={18} className="text-accent-orange" /> : someSelected ? <div className="w-[18px] h-[18px] flex items-center justify-center bg-accent-orange/20 rounded border border-accent-orange/50"><div className="w-2 h-0.5 bg-accent-orange rounded-full" /></div> : <Square size={18} className="text-text-tertiary" />}
                                                </div>
                                                <div className="flex-grow flex items-center justify-between">
                                                    <div className="flex items-center gap-2">
                                                        <span className="text-[10px] font-bold text-white uppercase tracking-widest group-hover:text-accent-orange transition-colors">{cat.replace(/_/g, ' ')}</span>
                                                        <span className="text-[8px] font-mono text-text-tertiary">({selectedCount}/{checks.length})</span>
                                                    </div>
                                                    {isExpanded ? <ChevronDown size={14} className="text-text-tertiary" /> : <ChevronRight size={14} className="text-text-tertiary" />}
                                                </div>
                                            </div>

                                            {isExpanded && (
                                                <div className="bg-bg-secondary divide-y divide-border-medium/30 border-t border-border-medium/30">
                                                    {checks.map(check => (
                                                        <div 
                                                            key={check.id} 
                                                            className="flex items-start gap-4 p-4 hover:bg-accent-orange/5 transition-all cursor-pointer"
                                                            onClick={() => toggleCheck(check.id)}
                                                        >
                                                            <div className="mt-1">
                                                                {selectedChecks.has(check.id) ? <CheckCircle2 size={16} className="text-accent-orange" /> : <div className="w-4 h-4 rounded-md border border-border-medium" />}
                                                            </div>
                                                            <div className="flex-grow min-w-0">
                                                                <div className="flex items-center justify-between mb-1">
                                                                    <div className="flex items-center gap-2">
                                                                        <span className="text-[10px] font-mono font-bold text-accent-orange uppercase">{check.id}</span>
                                                                        <span className={clsx("text-[8px] font-bold px-1.5 py-0.5 rounded uppercase border", severityColors[check.severity.toLowerCase()] || severityColors.info)}>
                                                                            {check.severity}
                                                                        </span>
                                                                    </div>
                                                                    <span className="text-[8px] font-bold text-text-tertiary uppercase tracking-widest">{check.engine}</span>
                                                                </div>
                                                                <h3 className="text-xs font-bold text-white mb-1 leading-tight">{check.name}</h3>
                                                                <p className="text-[10px] text-text-tertiary line-clamp-1 italic">{check.description}</p>
                                                            </div>
                                                        </div>
                                                    ))}
                                                </div>
                                            )}
                                        </div>
                                    );
                                })
                            )}
                        </div>
                    </div>
                </div>
            </div>

            {/* Results Section */}
            {scanResults && (
                <div className="mt-8 bg-bg-tertiary border border-border-medium rounded-2xl p-6 shadow-xl animate-in fade-in slide-in-from-bottom-6 duration-500">
                    <div className="flex items-center justify-between mb-8 border-b border-white/5 pb-4">
                        <div className="flex items-center gap-4">
                            <div className="p-3 bg-green-500/10 rounded-2xl"><Activity size={24} className="text-green-500" /></div>
                            <div>
                                <h2 className="text-xl font-bold text-white tracking-tight">Vulnerability Attack Path Intelligence</h2>
                                <p className="text-[10px] text-text-tertiary uppercase font-bold tracking-widest mt-1">Generated relationship analysis</p>
                            </div>
                        </div>
                        <button 
                             onClick={() => navigate('/analysis')}
                             className="px-6 py-2 bg-white/5 hover:bg-white/10 border border-border-medium rounded-xl text-[10px] font-bold uppercase tracking-widest text-white transition-all shadow-sm"
                        >
                            Deep Analysis
                        </button>
                    </div>

                    <div className="min-h-[320px] border border-border-medium rounded-2xl overflow-hidden bg-bg-secondary relative">
                        {scanResults.graphData ? (
                            <div className="h-[500px]">
                                <GraphVisualizer data={scanResults.graphData} />
                            </div>
                        ) : (
                            <div className="p-8 space-y-4 text-text-secondary">
                                <p className="text-sm text-text-primary">
                                    No attack-path graph was returned for this run. Below is the scan summary from the
                                    engine output (when available).
                                </p>
                                {scanResults.summary &&
                                typeof scanResults.summary === 'object' &&
                                Object.keys(scanResults.summary).length > 0 ? (
                                    <pre className="text-xs font-mono bg-bg-primary/80 border border-border-medium rounded-xl p-4 overflow-auto max-h-80 text-left">
                                        {JSON.stringify(scanResults.summary, null, 2)}
                                    </pre>
                                ) : (
                                    <p className="text-sm italic">No summary fields were parsed from scan-results.json.</p>
                                )}
                                {scanResults.scanResultsPath && (
                                    <p className="text-[10px] font-mono text-text-tertiary break-all">
                                        Output: {String(scanResults.scanResultsPath)}
                                    </p>
                                )}
                            </div>
                        )}
                    </div>
                </div>
            )}
        </div>
    );
}

// Hook a dummy Graph icon for the results section
// @ts-ignore
GraphVisualizer.Icon = Activity;
