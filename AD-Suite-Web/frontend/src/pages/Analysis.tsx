import { useState, useMemo, useCallback, useRef } from 'react';
import { useQuery } from '@tanstack/react-query';
import {
    Upload, ChevronDown, ChevronUp, Download, AlertCircle,
    Activity, Shield, TrendingUp, FileWarning, Server, Clock,
    Database, ChevronRight, ExternalLink, X
} from 'lucide-react';
import api from '../lib/api';
import { useSettings } from '../contexts/SettingsContext';
import { useAppStore } from '../store/useAppStore';
import { useFindingsStore } from '../store/useFindingsStore';

/* ─── Types ─── */
interface ScanFinding { [key: string]: any; }

interface ScanResult {
    CheckId: string;
    CheckName: string;
    Category: string;
    Severity: string;
    Result: string;
    FindingCount: number;
    CheckScore: number;
    DurationMs: number;
    Error: string | null;
    Description: string | null;
    Remediation: string | null;
    References: string[] | string | null;
    Findings: ScanFinding[];
    SourcePath: string | null;
    ScoreWeight: number;
}

interface ScanDocument {
    schemaVersion?: number;
    meta?: Record<string, any>;
    aggregate?: {
        checksRun: number;
        checksWithFindings: number;
        checksWithErrors: number;
        totalFindings: number;
        globalRaw: number;
        globalScore: number;
        globalRiskBand: string;
        scoreByCategory?: Record<string, number>;
    };
    byCategory?: Record<string, { checks: number; withFindings: number; errors: number }>;
    results?: ScanResult[];
}

interface UploadedFile {
    filename: string;
    size: number;
    uploadedAt: string;
}

type SortDir = 1 | -1;
type SortKey = keyof ScanResult;

/* ─── Helpers ─── */
const sevColor: Record<string, string> = {
    critical: 'text-critical',
    high: 'text-high',
    medium: 'text-medium',
    low: 'text-low',
    info: 'text-info',
};

const sevBg: Record<string, string> = {
    critical: 'bg-critical/10',
    high: 'bg-high/10',
    medium: 'bg-medium/10',
    low: 'bg-low/10',
    info: 'bg-info/10',
};

const resultColor: Record<string, string> = {
    pass: 'text-green-500',
    fail: 'text-medium',
    error: 'text-critical',
};

const riskBandColor: Record<string, string> = {
    Low: 'text-green-500',
    Moderate: 'text-medium',
    High: 'text-high',
    Critical: 'text-critical',
};

function formatBytes(b: number) {
    if (b < 1024) return b + ' B';
    if (b < 1024 * 1024) return (b / 1024).toFixed(1) + ' KB';
    return (b / (1024 * 1024)).toFixed(1) + ' MB';
}

/* ─── Subcomponents ─── */
function StatCard({ title, value, icon: Icon, color, bg }: {
    title: string; value: string | number; icon: any; color: string; bg: string;
}) {
    return (
        <div className="bg-surface-elevated border border-border-light rounded-xl p-5 hover:shadow-md transition-all duration-200">
            <div className="flex items-center justify-between mb-3">
                <span className="text-sm font-medium text-text-secondary">{title}</span>
                <div className={`p-2 rounded-lg ${bg}`}><Icon className={color} size={18} /></div>
            </div>
            <div className={`text-3xl font-semibold ${color}`}>{value}</div>
        </div>
    );
}

function FilterChips({ items, active, onToggle, label }: {
    items: string[]; active: Set<string>; onToggle: (v: string | null) => void; label: string;
}) {
    return (
        <div className="flex flex-wrap gap-2">
            <button
                onClick={() => onToggle(null)}
                className={`px-3 py-1.5 rounded-full text-sm font-medium border transition-all duration-150 ${
                    active.size === 0
                        ? 'border-accent-orange text-accent-orange bg-accent-orange-light'
                        : 'border-border-medium text-text-secondary hover:text-text-primary hover:bg-bg-hover'
                }`}
            >
                All {label}
            </button>
            {items.map(item => (
                <button
                    key={item}
                    onClick={() => onToggle(item)}
                    className={`px-3 py-1.5 rounded-full text-sm border transition-all duration-150 ${
                        active.has(item)
                            ? 'border-accent-orange text-accent-orange bg-accent-orange-light font-medium'
                            : 'border-border-medium text-text-secondary hover:text-text-primary hover:bg-bg-hover'
                    }`}
                >
                    {item}
                </button>
            ))}
        </div>
    );
}

function SortableHeader({ label, sortKey: sk, currentKey, dir, onSort }: {
    label: string; sortKey: SortKey; currentKey: SortKey; dir: SortDir; onSort: (k: SortKey) => void;
}) {
    const active = currentKey === sk;
    return (
        <th
            className="px-3 py-3 text-left text-xs font-semibold text-text-secondary uppercase tracking-wider cursor-pointer hover:text-text-primary select-none transition-colors"
            onClick={() => onSort(sk)}
        >
            <div className="flex items-center gap-1">
                {label}
                {active && (dir === 1 ? <ChevronUp size={14} /> : <ChevronDown size={14} />)}
            </div>
        </th>
    );
}

function DrillDown({ result }: { result: ScanResult }) {
    const [open, setOpen] = useState(false);
    const findings = result.Findings || [];
    const preview = findings.slice(0, 15);
    const refs = result.References;
    const { tableDensity } = useSettings();
    const cellPad = tableDensity === 'compact' ? 'py-1.5' : tableDensity === 'spacious' ? 'py-4' : 'py-3';

    return (
        <td className={`px-3 ${cellPad}`}>
            <button
                onClick={() => setOpen(!open)}
                className="flex items-center gap-1 text-accent-orange hover:text-accent-orange-hover text-sm font-medium transition-colors"
            >
                <ChevronRight size={14} className={`transition-transform ${open ? 'rotate-90' : ''}`} />
                Details
            </button>
            {open && (
                <div className="mt-3 p-4 bg-bg-secondary border border-border-light rounded-lg text-sm space-y-3">
                    {result.Description && (
                        <p><span className="font-semibold text-text-primary">Description:</span>{' '}
                            <span className="text-text-secondary">{result.Description}</span></p>
                    )}
                    {result.Remediation && (
                        <p><span className="font-semibold text-text-primary">Remediation:</span>{' '}
                            <span className="text-text-secondary">{result.Remediation}</span></p>
                    )}
                    {refs && (
                        <div>
                            <span className="font-semibold text-text-primary">References:</span>
                            <ul className="mt-1 space-y-1 list-disc list-inside text-text-secondary">
                                {(Array.isArray(refs) ? refs : [refs]).map((r, i) => (
                                    <li key={i}>{r.startsWith('http') ? (
                                        <a href={r} target="_blank" rel="noreferrer" className="text-accent-orange hover:underline inline-flex items-center gap-1">
                                            {r} <ExternalLink size={12} />
                                        </a>
                                    ) : r}</li>
                                ))}
                            </ul>
                        </div>
                    )}
                    {result.Error && (
                        <p className="text-critical"><span className="font-semibold">Error:</span> {result.Error}</p>
                    )}
                    {preview.length > 0 ? (
                        <div>
                            <p className="font-semibold text-text-primary mb-2">Findings preview (first {preview.length})</p>
                            <div className="overflow-auto max-h-64 border border-border-light rounded-lg">
                                <table className="w-full text-xs">
                                    <thead>
                                        <tr className="bg-bg-tertiary">
                                            {Object.keys(preview[0])
                                                .filter(k => !['CheckId','CheckName','FindingCount','Result','Severity','Description'].includes(k))
                                                .slice(0, 10)
                                                .map(k => <th key={k} className="px-2 py-1.5 text-left font-semibold text-text-secondary border-b border-border-light">{k}</th>)}
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {preview.map((row, ri) => (
                                            <tr key={ri} className="border-b border-border-light last:border-0 hover:bg-bg-hover">
                                                {Object.keys(preview[0])
                                                    .filter(k => !['CheckId','CheckName','FindingCount','Result','Severity','Description'].includes(k))
                                                    .slice(0, 10)
                                                    .map(k => <td key={k} className="px-2 py-1.5 text-text-secondary max-w-[250px] truncate">{String(row[k] ?? '')}</td>)}
                                            </tr>
                                        ))}
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    ) : (
                        <p className="text-text-tertiary italic">No finding rows (Pass)</p>
                    )}
                </div>
            )}
        </td>
    );
}


/* ─── Main component ─── */
export default function Analysis() {
    const [scanDoc, setScanDoc] = useState<ScanDocument | null>(null);
    const [filterCats, setFilterCats] = useState<Set<string>>(new Set());
    const [filterSevs, setFilterSevs] = useState<Set<string>>(new Set());
    const [sortKey, setSortKey] = useState<SortKey>('CheckId');
    const [sortDir, setSortDir] = useState<SortDir>(1);
    const [uploading, setUploading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [loadedName, setLoadedName] = useState<string | null>(null);
    const [showServerFiles, setShowServerFiles] = useState(false);
    const fileRef = useRef<HTMLInputElement>(null);
    const { tableDensity } = useSettings();
    const { addScanHistory, setActiveScanId } = useAppStore();
    const { setFindings } = useFindingsStore();

    const thPad = tableDensity === 'compact' ? 'py-2' : tableDensity === 'spacious' ? 'py-4' : 'py-3';
    const tdPad = tableDensity === 'compact' ? 'py-1.5' : tableDensity === 'spacious' ? 'py-4' : 'py-2.5';

    // Fetch uploaded scans from server
    const { data: serverScans, refetch: refetchScans } = useQuery({
        queryKey: ['analysis-scans'],
        queryFn: async () => {
            const r = await api.get('/analysis/scans');
            return r.data.scans as UploadedFile[];
        },
        retry: false,
        enabled: false // only fetch on demand
    });

    /* ─── File loading ─── */
    const normalizeScanDoc = useCallback((raw: any): ScanDocument => {
        if (!raw || typeof raw !== 'object') {
            return { schemaVersion: 1, meta: {}, aggregate: {} as any, results: [] };
        }

        let c = raw;
        if (raw.data && typeof raw.data === 'object' && !raw.results && !raw.Results && !raw.aggregate && !raw.Aggregate) {
            c = raw.data;
        } else if (raw.scan && typeof raw.scan === 'object' && !raw.results && !raw.Results && !raw.aggregate && !raw.Aggregate) {
            c = raw.scan;
        }

        let rawResults = Array.isArray(c) ? c : (c.results ?? c.Results ?? []);

        // Normalize keys for each result to standard PascalCase so the UI bindings work
        const normalizedResults = rawResults.map((r: any) => ({
            CheckId: r.CheckId ?? r.checkId,
            CheckName: r.CheckName ?? r.checkName ?? r.Name ?? r.name,
            Category: r.Category ?? r.category,
            Severity: r.Severity ?? r.severity,
            Result: r.Result ?? r.result,
            FindingCount: r.FindingCount ?? r.findingCount,
            CheckScore: r.CheckScore ?? r.checkScore,
            DurationMs: r.DurationMs ?? r.durationMs,
            Error: r.Error ?? r.error,
            Description: r.Description ?? r.description,
            Remediation: r.Remediation ?? r.remediation,
            References: r.References ?? r.references,
            Findings: r.Findings ?? r.findings ?? [],
            SourcePath: r.SourcePath ?? r.sourcePath,
            ScoreWeight: r.ScoreWeight ?? r.scoreWeight
        }));

        return {
            schemaVersion: c.schemaVersion ?? c.SchemaVersion ?? 1,
            meta: c.meta ?? c.Meta ?? {},
            aggregate: c.aggregate ?? c.Aggregate ?? {},
            byCategory: c.byCategory ?? c.ByCategory ?? undefined,
            results: normalizedResults,
        } as ScanDocument;
    }, []);

    const loadFromFile = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        if (!file) return;
        setError(null);
        const reader = new FileReader();
        reader.onload = () => {
            try {
                const raw = JSON.parse(reader.result as string);
                const doc = normalizeScanDoc(raw);
                setScanDoc(doc);
                setLoadedName(file.name);
                setFilterCats(new Set());
                setFilterSevs(new Set());
                
                // Dispatch to Global Stores
                const scanId = 'local-' + file.name + '-' + Date.now();
                setActiveScanId(scanId);
                setFindings(scanId, doc.results?.flatMap((r: any) => r.Findings || []) || []);
                addScanHistory({
                    id: scanId,
                    timestamp: doc.meta?.Timestamp ? new Date(doc.meta.Timestamp).getTime() : Date.now(),
                    totalFindings: doc.aggregate?.totalFindings || 0,
                    durationMs: 0,
                    status: 'success'
                });
            } catch (err: any) {
                setError('Invalid scan-results JSON: ' + err.message);
            }
        };
        reader.readAsText(file);
        e.target.value = '';
    }, [normalizeScanDoc]);

    const uploadToServer = useCallback(async (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        if (!file) return;
        setError(null);
        setUploading(true);
        try {
            const fd = new FormData();
            fd.append('file', file);
            await api.post('/analysis/upload', fd, { headers: { 'Content-Type': 'multipart/form-data' } });
            // Also load it locally
            const reader = new FileReader();
            reader.onload = () => {
                try {
                    const raw = JSON.parse(reader.result as string);
                    const doc = normalizeScanDoc(raw);
                    setScanDoc(doc);
                    setLoadedName(file.name);
                    setFilterCats(new Set());
                    setFilterSevs(new Set());
                    
                    const scanId = file.name;
                    setActiveScanId(scanId);
                    setFindings(scanId, doc.results?.flatMap((r: any) => r.Findings || []) || []);
                    addScanHistory({
                        id: scanId,
                        timestamp: Date.now(),
                        totalFindings: doc.aggregate?.totalFindings || 0,
                        durationMs: 0,
                        status: 'success'
                    });
                } catch { /* already uploaded */ }
            };
            reader.readAsText(file);
            refetchScans();
        } catch (err: any) {
            setError(err.response?.data?.message || 'Upload failed');
        } finally {
            setUploading(false);
            e.target.value = '';
        }
    }, [refetchScans]);

    const loadFromServer = useCallback(async (filename: string) => {
        setError(null);
        try {
            const r = await api.get(`/analysis/scans/${filename}`);
            const doc = normalizeScanDoc(r.data);
            setScanDoc(doc);
            setLoadedName(filename);
            setFilterCats(new Set());
            setFilterSevs(new Set());
            setShowServerFiles(false);
            
            const scanId = filename;
            setActiveScanId(scanId);
            setFindings(scanId, doc.results?.flatMap((r: any) => r.Findings || []) || []);
            addScanHistory({
                id: scanId,
                timestamp: doc.meta?.Timestamp ? new Date(doc.meta.Timestamp).getTime() : Date.now(),
                totalFindings: doc.aggregate?.totalFindings || 0,
                durationMs: 0,
                status: 'success'
            });
        } catch (err: any) {
            setError(err.response?.data?.message || 'Failed to load scan');
        }
    }, []);

    /* ─── Filtering & sorting ─── */
    const results = scanDoc?.results || [];
    const categories = useMemo(() => [...new Set(results.map(r => r.Category).filter(Boolean))].sort(), [results]);
    const severities = useMemo(() => [...new Set(results.map(r => (r.Severity || '').toLowerCase()).filter(Boolean))].sort(), [results]);

    const toggleCat = useCallback((cat: string | null) => {
        if (cat === null) { setFilterCats(new Set()); return; }
        setFilterCats(prev => {
            const next = new Set(prev);
            next.has(cat) ? next.delete(cat) : next.add(cat);
            return next;
        });
    }, []);

    const toggleSev = useCallback((sev: string | null) => {
        if (sev === null) { setFilterSevs(new Set()); return; }
        setFilterSevs(prev => {
            const next = new Set(prev);
            next.has(sev) ? next.delete(sev) : next.add(sev);
            return next;
        });
    }, []);

    const filtered = useMemo(() => {
        let rows = results;
        if (filterCats.size > 0) rows = rows.filter(r => filterCats.has(r.Category));
        if (filterSevs.size > 0) rows = rows.filter(r => filterSevs.has((r.Severity || '').toLowerCase()));
        return rows.slice().sort((a, b) => {
            const va = a[sortKey] ?? '';
            const vb = b[sortKey] ?? '';
            if (typeof va === 'number' && typeof vb === 'number') return (va - vb) * sortDir;
            return String(va).localeCompare(String(vb), undefined, { numeric: true }) * sortDir;
        });
    }, [results, filterCats, filterSevs, sortKey, sortDir]);

    const onSort = useCallback((k: SortKey) => {
        setSortDir(prev => sortKey === k ? (prev === 1 ? -1 : 1) as SortDir : 1);
        setSortKey(k);
    }, [sortKey]);

    const top10 = useMemo(
        () => results.filter(r => (r.CheckScore || 0) > 0).sort((a, b) => (b.CheckScore || 0) - (a.CheckScore || 0)).slice(0, 10),
        [results]
    );

    /* ─── Export ─── */
    const downloadFiltered = useCallback(() => {
        const out = { schemaVersion: 1, filteredFrom: scanDoc?.meta, aggregate: scanDoc?.aggregate, results: filtered };
        const blob = new Blob([JSON.stringify(out, null, 2)], { type: 'application/json' });
        const a = document.createElement('a');
        a.href = URL.createObjectURL(blob);
        a.download = 'scan-filtered.json';
        a.click();
        URL.revokeObjectURL(a.href);
    }, [filtered, scanDoc]);

    /* ─── Render ─── */
    const agg = scanDoc?.aggregate;
    const meta = scanDoc?.meta;
    const byCat = scanDoc?.byCategory;
    const scoreByCat = agg?.scoreByCategory;

    return (
        <div className="space-y-6">
            {/* Header */}
            <div>
                <h1 className="text-3xl font-semibold text-text-primary mb-2">Analysis Dashboard</h1>
                <p className="text-md text-text-secondary">Load a scan-results.json to view scores, checks, and findings.</p>
            </div>

            {/* Upload bar */}
            <div className="bg-surface-elevated border border-border-light rounded-xl p-5">
                <div className="flex flex-wrap items-center gap-3">
                    <label className="flex items-center gap-2 bg-accent-orange hover:bg-accent-orange-hover text-white font-medium px-5 py-2.5 rounded-lg cursor-pointer transition-all duration-150 active:scale-[0.98] shadow-sm">
                        <Upload size={18} />
                        Load scan results
                        <input ref={fileRef} type="file" accept=".json,application/json" className="hidden" onChange={loadFromFile} />
                    </label>
                    <label className="flex items-center gap-2 bg-bg-tertiary border border-border-medium text-text-secondary hover:text-text-primary hover:bg-bg-hover font-medium px-5 py-2.5 rounded-lg cursor-pointer transition-all duration-150">
                        <Upload size={18} />
                        {uploading ? 'Uploading…' : 'Upload & save to server'}
                        <input type="file" accept=".json,application/json" className="hidden" onChange={uploadToServer} disabled={uploading} />
                    </label>
                    <button
                        onClick={() => { setShowServerFiles(v => !v); refetchScans(); }}
                        className="flex items-center gap-2 px-4 py-2.5 bg-bg-tertiary border border-border-medium rounded-lg text-sm font-medium text-text-secondary hover:text-text-primary hover:bg-bg-hover transition-all"
                    >
                        <Server size={18} />
                        Server files
                    </button>
                    {loadedName && (
                        <span className="ml-auto px-3 py-1.5 bg-bg-tertiary rounded-lg text-sm text-text-secondary font-mono flex items-center gap-2">
                            {loadedName}
                            <button onClick={() => { setScanDoc(null); setLoadedName(null); }} className="hover:text-text-primary"><X size={14} /></button>
                        </span>
                    )}
                </div>
                {error && (
                    <div className="mt-3 bg-critical/10 border border-critical/30 text-critical px-4 py-3 rounded-lg text-sm">
                        {error}
                    </div>
                )}
                {showServerFiles && serverScans && (
                    <div className="mt-3 border border-border-light rounded-lg overflow-hidden">
                        {serverScans.length === 0 ? (
                            <p className="p-4 text-sm text-text-tertiary">No uploaded scans on server.</p>
                        ) : (
                            <table className="w-full text-sm">
                                <thead><tr className="bg-bg-tertiary">
                                    <th className="px-3 py-2 text-left text-xs font-semibold text-text-secondary">Filename</th>
                                    <th className="px-3 py-2 text-left text-xs font-semibold text-text-secondary">Size</th>
                                    <th className="px-3 py-2 text-left text-xs font-semibold text-text-secondary">Uploaded</th>
                                    <th className="px-3 py-2"></th>
                                </tr></thead>
                                <tbody>
                                    {serverScans.map(f => (
                                        <tr key={f.filename} className="border-t border-border-light hover:bg-bg-hover">
                                            <td className="px-3 py-2 font-mono text-text-primary">{f.filename}</td>
                                            <td className="px-3 py-2 text-text-secondary">{formatBytes(f.size)}</td>
                                            <td className="px-3 py-2 text-text-secondary">{new Date(f.uploadedAt).toLocaleString()}</td>
                                            <td className="px-3 py-2">
                                                <button onClick={() => loadFromServer(f.filename)} className="text-accent-orange hover:underline text-sm font-medium">Load</button>
                                            </td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        )}
                    </div>
                )}
            </div>

            {/* Empty state */}
            {!scanDoc && (
                <div className="bg-surface-elevated border border-border-light rounded-xl p-10 text-center">
                    <div className="w-16 h-16 rounded-full bg-bg-tertiary flex items-center justify-center mx-auto mb-4">
                        <Activity size={24} className="text-text-tertiary" />
                    </div>
                    <h3 className="text-lg font-semibold text-text-primary mb-2">No scan loaded</h3>
                    <p className="text-sm text-text-secondary">Choose a scan-results.json file to visualize scores, checks, and findings.</p>
                </div>
            )}

            {/* ─── Loaded scan ─── */}
            {scanDoc && agg && (
                <>
                    {/* Summary cards */}
                    <div className="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-5 gap-4">
                        <StatCard title="Global Risk" value={`${agg.globalScore ?? '—'} / 100`} icon={Shield}
                            color={riskBandColor[agg.globalRiskBand] || 'text-text-primary'} bg={sevBg[(agg.globalRiskBand || '').toLowerCase()] || 'bg-bg-tertiary'} />
                        <StatCard title="Checks Run" value={agg.checksRun ?? '—'} icon={Activity} color="text-low" bg="bg-low/10" />
                        <StatCard title="With Findings" value={agg.checksWithFindings ?? '—'} icon={AlertCircle} color="text-medium" bg="bg-medium/10" />
                        <StatCard title="Errors" value={agg.checksWithErrors ?? '—'} icon={FileWarning} color="text-critical" bg="bg-critical/10" />
                        <StatCard title="Total Findings" value={agg.totalFindings ?? '—'} icon={TrendingUp} color="text-accent-orange" bg="bg-accent-orange-light" />
                    </div>

                    {/* Meta block */}
                    {meta && (
                        <div className="bg-surface-elevated border border-border-light rounded-xl p-5 text-sm text-text-secondary space-y-1">
                            {meta.scanTimeUtc && <p className="flex items-center gap-2"><Clock size={14} /> <span className="font-medium text-text-primary">Scan (UTC):</span> {meta.scanTimeUtc}</p>}
                            {meta.serverName && <p className="flex items-center gap-2"><Server size={14} /> <span className="font-medium text-text-primary">Server:</span> {meta.serverName}</p>}
                            {meta.defaultNamingContext && <p className="flex items-center gap-2"><Database size={14} /> <span className="font-medium text-text-primary">Default NC:</span> {meta.defaultNamingContext}</p>}
                            {meta.checksJsonPath && <p><span className="font-medium text-text-primary">Catalog:</span> {meta.checksJsonPath}</p>}
                            {(meta.packName || meta.packVersion) && <p><span className="font-medium text-text-primary">Rule pack:</span> {meta.packName} {meta.packVersion}</p>}
                            <p><span className="font-medium text-text-primary">Risk band:</span>{' '}
                                <span className={`font-semibold ${riskBandColor[agg.globalRiskBand] || ''}`}>{agg.globalRiskBand}</span></p>
                        </div>
                    )}

                    {/* By category table */}
                    {byCat && Object.keys(byCat).length > 0 && (
                        <div>
                            <h2 className="text-xl font-semibold text-text-primary mb-3 flex items-center gap-2">
                                <div className="w-1 h-5 bg-accent-orange rounded-full" /> By category
                            </h2>
                            <div className="overflow-auto border border-border-light rounded-xl">
                                <table className="w-full text-sm">
                                    <thead><tr className="bg-bg-tertiary">
                                        <th className={`px-3 ${thPad} text-left text-xs font-semibold text-text-secondary uppercase`}>Category</th>
                                        <th className={`px-3 ${thPad} text-left text-xs font-semibold text-text-secondary uppercase`}>Checks</th>
                                        <th className={`px-3 ${thPad} text-left text-xs font-semibold text-text-secondary uppercase`}>With findings</th>
                                        <th className={`px-3 ${thPad} text-left text-xs font-semibold text-text-secondary uppercase`}>Errors</th>
                                        <th className={`px-3 ${thPad} text-left text-xs font-semibold text-text-secondary uppercase`}>Raw score</th>
                                    </tr></thead>
                                    <tbody>
                                        {Object.keys(byCat).sort().map(k => {
                                            const row = byCat[k];
                                            return (
                                                <tr key={k} className="border-t border-border-light hover:bg-bg-hover">
                                                    <td className={`px-3 ${tdPad} font-medium text-text-primary`}>{k}</td>
                                                    <td className={`px-3 ${tdPad} text-text-secondary`}>{row.checks}</td>
                                                    <td className={`px-3 ${tdPad} text-text-secondary`}>{row.withFindings}</td>
                                                    <td className={`px-3 ${tdPad} text-text-secondary`}>{row.errors}</td>
                                                    <td className={`px-3 ${tdPad} text-text-secondary font-mono`}>{scoreByCat?.[k] ?? ''}</td>
                                                </tr>
                                            );
                                        })}
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    )}

                    {/* Top 10 risks */}
                    {top10.length > 0 && (
                        <div>
                            <h2 className="text-xl font-semibold text-text-primary mb-3 flex items-center gap-2">
                                <div className="w-1 h-5 bg-accent-orange rounded-full" /> Top risks (by score)
                            </h2>
                            <div className="overflow-auto border border-border-light rounded-xl">
                                <table className="w-full text-sm">
                                    <thead><tr className="bg-bg-tertiary">
                                        <th className={`px-3 ${thPad} text-left text-xs font-semibold text-text-secondary uppercase`}>CheckId</th>
                                        <th className={`px-3 ${thPad} text-left text-xs font-semibold text-text-secondary uppercase`}>Name</th>
                                        <th className={`px-3 ${thPad} text-left text-xs font-semibold text-text-secondary uppercase`}>Category</th>
                                        <th className={`px-3 ${thPad} text-left text-xs font-semibold text-text-secondary uppercase`}>Severity</th>
                                        <th className={`px-3 ${thPad} text-left text-xs font-semibold text-text-secondary uppercase`}>Findings</th>
                                        <th className={`px-3 ${thPad} text-left text-xs font-semibold text-text-secondary uppercase`}>Score</th>
                                    </tr></thead>
                                    <tbody>
                                        {top10.map(r => (
                                            <tr key={r.CheckId} className="border-t border-border-light hover:bg-bg-hover">
                                                <td className={`px-3 ${tdPad} font-mono text-text-primary`}>{r.CheckId}</td>
                                                <td className={`px-3 ${tdPad} text-text-primary`}>{r.CheckName}</td>
                                                <td className={`px-3 ${tdPad} text-text-secondary`}>{r.Category}</td>
                                                <td className={`px-3 ${tdPad} font-semibold ${sevColor[(r.Severity || '').toLowerCase()] || ''}`}>{r.Severity}</td>
                                                <td className={`px-3 ${tdPad} text-text-secondary font-mono`}>{r.FindingCount}</td>
                                                <td className={`px-3 ${tdPad} text-text-primary font-mono font-semibold`}>{r.CheckScore}</td>
                                            </tr>
                                        ))}
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    )}

                    {/* Filters */}
                    <div className="space-y-4">
                        <div>
                            <h2 className="text-xl font-semibold text-text-primary mb-3 flex items-center gap-2">
                                <div className="w-1 h-5 bg-accent-orange rounded-full" /> Filter by category
                            </h2>
                            <FilterChips items={categories} active={filterCats} onToggle={toggleCat} label="categories" />
                        </div>
                        <div>
                            <h2 className="text-xl font-semibold text-text-primary mb-3 flex items-center gap-2">
                                <div className="w-1 h-5 bg-accent-orange rounded-full" /> Filter by severity
                            </h2>
                            <FilterChips items={severities} active={filterSevs} onToggle={toggleSev} label="severities" />
                        </div>
                    </div>

                    {/* Toolbar */}
                    <div className="flex gap-3">
                        <button onClick={downloadFiltered}
                            className="flex items-center gap-2 px-4 py-2.5 bg-bg-tertiary border border-border-medium rounded-lg text-sm font-medium text-text-secondary hover:text-text-primary hover:bg-bg-hover transition-all">
                            <Download size={18} /> Download filtered JSON
                        </button>
                        <span className="self-center text-sm text-text-tertiary">{filtered.length} check(s) shown</span>
                    </div>

                    {/* All checks table */}
                    <div>
                        <h2 className="text-xl font-semibold text-text-primary mb-3 flex items-center gap-2">
                            <div className="w-1 h-5 bg-accent-orange rounded-full" /> All checks
                        </h2>
                        <div className="overflow-auto border border-border-light rounded-xl">
                            <table className="w-full text-sm">
                                <thead><tr className="bg-bg-tertiary">
                                    <SortableHeader label="CheckId" sortKey="CheckId" currentKey={sortKey} dir={sortDir} onSort={onSort} />
                                    <SortableHeader label="Name" sortKey="CheckName" currentKey={sortKey} dir={sortDir} onSort={onSort} />
                                    <SortableHeader label="Category" sortKey="Category" currentKey={sortKey} dir={sortDir} onSort={onSort} />
                                    <SortableHeader label="Severity" sortKey="Severity" currentKey={sortKey} dir={sortDir} onSort={onSort} />
                                    <SortableHeader label="Result" sortKey="Result" currentKey={sortKey} dir={sortDir} onSort={onSort} />
                                    <SortableHeader label="Findings" sortKey="FindingCount" currentKey={sortKey} dir={sortDir} onSort={onSort} />
                                    <SortableHeader label="Score" sortKey="CheckScore" currentKey={sortKey} dir={sortDir} onSort={onSort} />
                                    <th className={`px-3 ${thPad} text-left text-xs font-semibold text-text-secondary uppercase`}>Details</th>
                                </tr></thead>
                                <tbody>
                                    {filtered.map(r => (
                                        <tr key={r.CheckId} className="border-t border-border-light hover:bg-bg-hover">
                                            <td className={`px-3 ${tdPad} font-mono text-text-primary`}>{r.CheckId}</td>
                                            <td className={`px-3 ${tdPad} text-text-primary`}>{r.CheckName}</td>
                                            <td className={`px-3 ${tdPad} text-text-secondary`}>{r.Category}</td>
                                            <td className={`px-3 ${tdPad} font-semibold ${sevColor[(r.Severity || '').toLowerCase()] || ''}`}>{r.Severity}</td>
                                            <td className={`px-3 ${tdPad} font-medium ${resultColor[(r.Result || '').toLowerCase()] || 'text-text-secondary'}`}>{r.Result}</td>
                                            <td className={`px-3 ${tdPad} text-text-secondary font-mono`}>{r.FindingCount}</td>
                                            <td className={`px-3 ${tdPad} text-text-primary font-mono font-semibold`}>{r.CheckScore}</td>
                                            <DrillDown result={r} />
                                        </tr>
                                    ))}
                                    {filtered.length === 0 && (
                                        <tr><td colSpan={8} className="px-3 py-8 text-center text-text-tertiary">No checks match the current filters.</td></tr>
                                    )}
                                </tbody>
                            </table>
                        </div>
                    </div>
                </>
            )}
        </div>
    );
}
