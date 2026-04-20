import { useEffect, useMemo, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { Plus, Search, Shield, Clock, AlertCircle, Loader2, Upload, Maximize2, Minimize2, Network } from 'lucide-react';
import api from '../lib/api';
import ScanEntityGraph from '../components/ScanEntityGraph';
import { extractEntityGraphFromFindings, flattenFindingRows } from '../lib/extractEntityGraph';
import { extractScanResultsArray } from '../lib/scanFindings';

interface ScanSummary {
    id: string;
    name: string;
    filename?: string;
    path?: string;
    status: string;
    timestamp: number;
    totalFindings: number;
    globalRiskBand: string;
    engine: string;
    severity: { critical: number; high: number; medium: number; low: number };
}

export default function Scans() {
    const [search, setSearch] = useState('');
    const [view, setView] = useState<'table' | 'graph'>('table');
    const [selectedScanId, setSelectedScanId] = useState<string>('');
    const [uploading, setUploading] = useState(false);
    const [uploadError, setUploadError] = useState<string | null>(null);
    const fileRef = useRef<HTMLInputElement>(null);
    const [isGraphFullscreen, setIsGraphFullscreen] = useState(false);
    const graphPanelRef = useRef<HTMLDivElement>(null);

    useEffect(() => {
        const onFullscreenChange = () => {
            setIsGraphFullscreen(document.fullscreenElement === graphPanelRef.current);
        };
        document.addEventListener('fullscreenchange', onFullscreenChange);
        return () => document.removeEventListener('fullscreenchange', onFullscreenChange);
    }, []);

    const toggleGraphFullscreen = async () => {
        const el = graphPanelRef.current;
        if (!el) return;
        try {
            if (!document.fullscreenElement) {
                await el.requestFullscreen();
            } else {
                await document.exitFullscreen();
            }
        } catch {
            /* ignore */
        }
    };

    const { data: scans, isLoading, isError, refetch: refetchScans } = useQuery({
        queryKey: ['scans-list'],
        queryFn: async () => (await api.get('/scans')).data as ScanSummary[]
    });

    const { data: selectedScanDetail, isLoading: isLoadingScanDetail } = useQuery({
        queryKey: ['scan-detail-for-graph', selectedScanId],
        queryFn: async () => (await api.get(`/scans/${encodeURIComponent(selectedScanId)}`)).data as any,
        enabled: view === 'graph' && Boolean(selectedScanId)
    });

    const filtered = useMemo(() => {
        if (!scans) return [];
        if (!search.trim()) return scans;
        const q = search.toLowerCase();
        return scans.filter(
            (s) => s.name.toLowerCase().includes(q) || s.id.toLowerCase().includes(q)
        );
    }, [scans, search]);

    const graph = useMemo(() => {
        const checks = extractScanResultsArray(selectedScanDetail);
        if (!checks.length) return null;
        const rows = flattenFindingRows(checks);
        const domain =
            String(selectedScanDetail?.meta?.defaultNamingContext ?? selectedScanDetail?.meta?.defaultNamingContext ?? 'Domain');
        return extractEntityGraphFromFindings(rows, { domainLabel: domain });
    }, [selectedScanDetail]);

    const uploadScanJson = async (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        if (!file) return;
        setUploadError(null);
        setUploading(true);
        try {
            const fd = new FormData();
            fd.append('file', file);
            const res = await api.post('/analysis/upload', fd, {
                headers: { 'Content-Type': 'multipart/form-data' }
            });
            await refetchScans();
            const filename = res.data?.filename as string | undefined;
            if (filename) {
                setView('graph');
                setSelectedScanId(filename);
            }
        } catch (err: any) {
            setUploadError(err?.response?.data?.message || err?.message || 'Upload failed');
        } finally {
            setUploading(false);
            e.target.value = '';
        }
    };

    return (
        <div>
            <div className="flex items-center justify-between mb-8">
                <div>
                    <h1 className="text-3xl font-semibold text-text-primary mb-2">Scans</h1>
                    <p className="text-md text-text-secondary">Manage your AD security scans</p>
                </div>
                <Link
                    to="/scans/new"
                    className="flex items-center gap-2 bg-accent-orange hover:bg-accent-orange-hover text-white font-medium px-5 py-2.5 rounded-lg transition-all duration-150 active:scale-[0.98] shadow-sm"
                >
                    <Plus size={18} />
                    New Scan
                </Link>
            </div>

            <div className="flex gap-3 mb-6">
                <div className="flex-1 relative">
                    <Search size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-text-tertiary" />
                    <input
                        type="text"
                        placeholder="Search scans..."
                        value={search}
                        onChange={(e) => setSearch(e.target.value)}
                        className="w-full pl-10 pr-4 py-2.5 bg-bg-tertiary border border-border-medium rounded-lg text-sm text-text-primary placeholder-text-tertiary focus:outline-none focus:border-accent-orange focus:ring-2 focus:ring-accent-orange/20 transition-all"
                    />
                </div>
            </div>

            <div className="flex items-center gap-2 mb-6">
                <button
                    type="button"
                    onClick={() => setView('table')}
                    className={`px-3 py-1.5 rounded-lg text-sm border ${
                        view === 'table'
                            ? 'bg-accent-orange-light/20 border-accent-orange/40 text-accent-orange'
                            : 'bg-bg-tertiary border-border-medium text-text-secondary hover:bg-bg-hover'
                    }`}
                >
                    Table
                </button>
                <button
                    type="button"
                    onClick={() => setView('graph')}
                    className={`px-3 py-1.5 rounded-lg text-sm border ${
                        view === 'graph'
                            ? 'bg-accent-orange-light/20 border-accent-orange/40 text-accent-orange'
                            : 'bg-bg-tertiary border-border-medium text-text-secondary hover:bg-bg-hover'
                    }`}
                >
                    Graph
                </button>
                {view === 'graph' && (
                    <div className="ml-auto flex items-center gap-2">
                        <label className={`inline-flex items-center gap-2 px-3 py-1.5 rounded-lg text-sm border transition-all ${
                            uploading
                                ? 'opacity-60 cursor-not-allowed bg-bg-tertiary border-border-medium text-text-tertiary'
                                : 'cursor-pointer bg-bg-tertiary border-border-medium text-text-secondary hover:bg-bg-hover hover:text-text-primary'
                        }`}>
                            <Upload size={16} />
                            {uploading ? 'Uploading…' : 'Upload JSON'}
                            <input
                                ref={fileRef}
                                type="file"
                                accept=".json,application/json"
                                className="hidden"
                                onChange={uploadScanJson}
                                disabled={uploading}
                            />
                        </label>
                        <span className="text-xs text-text-tertiary">Scan</span>
                        <select
                            value={selectedScanId}
                            onChange={(e) => setSelectedScanId(e.target.value)}
                            className="bg-bg-tertiary border border-border-medium rounded-lg px-3 py-1.5 text-sm text-text-primary outline-none focus:border-accent-orange"
                        >
                            <option value="">Select a scan…</option>
                            {(scans || []).map((s) => (
                                <option key={s.id} value={s.id}>
                                    {s.name} ({s.totalFindings})
                                </option>
                            ))}
                        </select>
                    </div>
                )}
            </div>

            {view === 'graph' && uploadError && (
                <div className="mb-6 p-4 rounded-xl border border-critical/30 bg-critical/5 text-critical text-sm">
                    {uploadError}
                </div>
            )}

            {isLoading && (
                <div className="flex items-center gap-3 text-text-secondary py-12 justify-center">
                    <Loader2 className="animate-spin" size={22} />
                    Loading scans…
                </div>
            )}

            {isError && (
                <div className="p-6 rounded-xl border border-critical/30 bg-critical/5 text-critical text-sm">
                    Could not load scans. Sign in and ensure the backend is running.
                </div>
            )}

            {!isLoading && !isError && filtered.length === 0 && (
                <div className="bg-surface-elevated border border-border-light rounded-xl overflow-hidden">
                    <div className="p-8 text-center">
                        <div className="w-16 h-16 rounded-full bg-bg-tertiary flex items-center justify-center mx-auto mb-4">
                            <Plus size={24} className="text-text-tertiary" />
                        </div>
                        <h3 className="text-lg font-semibold text-text-primary mb-2">
                            {scans?.length === 0 ? 'No scans yet' : 'No matching scans'}
                        </h3>
                        <p className="text-sm text-text-secondary mb-6">
                            {scans?.length === 0
                                ? 'Get started by creating your first security scan'
                                : 'Try a different search term'}
                        </p>
                        {scans?.length === 0 && (
                            <Link
                                to="/scans/new"
                                className="inline-flex items-center gap-2 bg-accent-orange hover:bg-accent-orange-hover text-white font-medium px-5 py-2.5 rounded-lg transition-all duration-150 active:scale-[0.98]"
                            >
                                <Plus size={18} />
                                Create Scan
                            </Link>
                        )}
                    </div>
                </div>
            )}

            {!isLoading && !isError && view === 'graph' && (
                <div
                    ref={graphPanelRef}
                    className={`bg-surface-elevated border border-border-light rounded-xl p-5 shadow-sm min-h-[300px] ${
                        isGraphFullscreen ? 'min-h-screen flex flex-col rounded-none border-border-medium' : ''
                    }`}
                >
                    {graph && selectedScanId && !isLoadingScanDetail ? (
                        <div className="flex flex-wrap items-center justify-between gap-3 mb-4">
                            <h2 className="text-lg font-medium text-text-primary flex items-center gap-2">
                                <Network size={20} className="text-accent-orange" /> Entity graph
                            </h2>
                            <button
                                type="button"
                                onClick={toggleGraphFullscreen}
                                className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium rounded-lg border border-border-medium bg-bg-tertiary text-text-secondary hover:bg-bg-hover hover:text-text-primary transition-colors"
                                title={isGraphFullscreen ? 'Exit fullscreen (Esc)' : 'View graph fullscreen'}
                            >
                                {isGraphFullscreen ? (
                                    <>
                                        <Minimize2 size={16} /> Exit fullscreen
                                    </>
                                ) : (
                                    <>
                                        <Maximize2 size={16} /> Fullscreen
                                    </>
                                )}
                            </button>
                        </div>
                    ) : null}
                    {!selectedScanId ? (
                        <div className="text-sm text-text-tertiary">Select a scan to render the evidence-based entity graph.</div>
                    ) : isLoadingScanDetail ? (
                        <div className="flex items-center gap-3 text-text-secondary py-12 justify-center">
                            <Loader2 className="animate-spin" size={22} />
                            Loading scan…
                        </div>
                    ) : graph ? (
                        <div className={isGraphFullscreen ? 'flex-1 min-h-0 flex flex-col' : ''}>
                            <ScanEntityGraph graph={graph} isFullscreen={isGraphFullscreen} />
                        </div>
                    ) : (
                        <div className="text-sm text-text-tertiary">No graphable edges found in this scan’s findings.</div>
                    )}
                </div>
            )}

            {!isLoading && !isError && view === 'table' && filtered.length > 0 && (
                <div className="bg-surface-elevated border border-border-light rounded-xl overflow-hidden">
                    <table className="w-full text-sm">
                        <thead>
                            <tr className="bg-bg-tertiary border-b border-border-light text-left">
                                <th className="px-4 py-3 font-semibold text-text-secondary uppercase text-xs">
                                    Name
                                </th>
                                <th className="px-4 py-3 font-semibold text-text-secondary uppercase text-xs">
                                    Status
                                </th>
                                <th className="px-4 py-3 font-semibold text-text-secondary uppercase text-xs">
                                    Risk
                                </th>
                                <th className="px-4 py-3 font-semibold text-text-secondary uppercase text-xs">
                                    Findings
                                </th>
                                <th className="px-4 py-3 font-semibold text-text-secondary uppercase text-xs">
                                    Time
                                </th>
                            </tr>
                        </thead>
                        <tbody>
                            {filtered.map((scan) => (
                                <tr
                                    key={scan.path || scan.id}
                                    className="border-b border-border-light hover:bg-bg-hover transition-colors"
                                >
                                    <td className="px-4 py-3">
                                        <Link
                                            to={`/scans/${encodeURIComponent(scan.id)}`}
                                            className="font-medium text-text-primary hover:text-accent-orange"
                                        >
                                            {scan.name}
                                        </Link>
                                        <div className="text-xs text-text-tertiary font-mono mt-0.5">
                                            {scan.id}
                                        </div>
                                    </td>
                                    <td className="px-4 py-3">
                                        <span
                                            className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium ${
                                                scan.status === 'Complete'
                                                    ? 'bg-green-500/10 text-green-500 border border-green-500/20'
                                                    : scan.status === 'Warning'
                                                      ? 'bg-yellow-500/10 text-yellow-500 border border-yellow-500/20'
                                                      : 'bg-critical/10 text-critical border border-critical/20'
                                            }`}
                                        >
                                            {scan.status === 'Complete' ? (
                                                <Shield size={12} />
                                            ) : (
                                                <AlertCircle size={12} />
                                            )}
                                            {scan.status}
                                        </span>
                                    </td>
                                    <td
                                        className={`px-4 py-3 font-semibold ${
                                            scan.globalRiskBand?.toUpperCase() === 'CRITICAL'
                                                ? 'text-critical'
                                                : scan.globalRiskBand?.toUpperCase() === 'HIGH'
                                                  ? 'text-accent-orange'
                                                  : scan.globalRiskBand?.toUpperCase() === 'MEDIUM'
                                                    ? 'text-yellow-500'
                                                    : 'text-blue-400'
                                        }`}
                                    >
                                        {scan.globalRiskBand || '—'}
                                    </td>
                                    <td className="px-4 py-3 text-text-secondary font-mono">
                                        {scan.totalFindings}
                                    </td>
                                    <td className="px-4 py-3 text-text-secondary flex items-center gap-2">
                                        <Clock size={14} />
                                        {new Date(scan.timestamp).toLocaleString()}
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            )}
        </div>
    );
}
