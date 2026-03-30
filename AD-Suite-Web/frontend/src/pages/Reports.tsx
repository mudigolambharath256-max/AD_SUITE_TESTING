import React, { useState, useMemo } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
    FileText, Filter, Search, ChevronDown, ChevronUp, ChevronRight,
    Download, Trash2, CheckSquare, Square, AlertCircle, Shield, FileWarning, Clock
} from 'lucide-react';
import api from '../lib/api';
import { downloadBlob } from '../lib/download';
import { useSettings } from '../contexts/SettingsContext';

// --- Types ---
interface ReportSummary {
    id: string;
    name: string;
    status: string;
    timestamp: string | number;
    engine: string;
    severity: { critical: number; high: number; medium: number; low: number };
    totalFindings: number;
    globalRiskBand: string;
}

interface Finding {
    CheckId: string;
    CheckName: string;
    Category: string;
    Severity: string;
    [key: string]: any;
}

// --- Empty State Component ---
const EmptyState = () => (
    <div className="flex flex-col items-center justify-center p-16 text-center bg-surface-elevated border border-border-light rounded-xl">
        <svg className="w-24 h-24 mb-6 text-text-tertiary" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1" strokeLinecap="round" strokeLinejoin="round">
            <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
            <polyline points="14 2 14 8 20 8"></polyline>
            <line x1="16" y1="13" x2="8" y2="13"></line>
            <line x1="16" y1="17" x2="8" y2="17"></line>
            <polyline points="10 9 9 9 8 9"></polyline>
        </svg>
        <h3 className="text-xl font-semibold text-text-primary mb-2">No scans available</h3>
        <p className="text-text-secondary max-w-sm">
            It looks like there are no scan results available to report on. Run a new scan from the Scan Planner or upload a scan file.
        </p>
    </div>
);

// --- Findings Preview Component ---
const FindingsPreview = ({ scanId }: { scanId: string }) => {
    const { tableDensity } = useSettings();
    const cellPad = tableDensity === 'compact' ? 'py-1.5' : tableDensity === 'spacious' ? 'py-4' : 'py-3';

    const [search, setSearch] = useState('');
    const [selectedSev, setSelectedSev] = useState<string>('All');

    const { data, isLoading } = useQuery({
        queryKey: ['report-findings', scanId],
        queryFn: async () => (await api.get(`/reports/scans/${scanId}/findings`)).data.findings as Finding[]
    });

    if (isLoading) return <div className="p-4 text-text-secondary text-sm">Loading findings...</div>;
    if (!data) return <div className="p-4 text-text-secondary text-sm">Failed to load findings.</div>;

    const filtered = data.filter(f => {
        if (selectedSev !== 'All' && f.Severity?.toUpperCase() !== selectedSev.toUpperCase()) return false;
        if (search) {
            const q = search.toLowerCase();
            return f.CheckName?.toLowerCase().includes(q) || f.CheckId?.toLowerCase().includes(q);
        }
        return true;
    });

    return (
        <div className="p-5 bg-bg-tertiary border-x border-b border-border-light rounded-b-lg">
            <div className="flex gap-4 mb-4">
                <input 
                    type="text" placeholder="Search findings..." value={search} onChange={e => setSearch(e.target.value)}
                    className="flex-1 bg-surface-elevated border border-border-medium rounded-lg px-3 py-1.5 text-sm text-text-primary focus:border-accent-orange outline-none"
                />
                <select value={selectedSev} onChange={e => setSelectedSev(e.target.value)}
                    className="bg-surface-elevated border border-border-medium rounded-lg px-3 py-1.5 text-sm text-text-primary outline-none"
                >
                    <option value="All">All Severities</option>
                    <option value="Critical">Critical</option>
                    <option value="High">High</option>
                    <option value="Medium">Medium</option>
                    <option value="Low">Low</option>
                </select>
            </div>
            
            {filtered.length === 0 ? (
                <div className="text-sm text-text-secondary">No findings match the criteria.</div>
            ) : (
                <div className="max-h-96 overflow-auto border border-border-medium rounded-lg">
                    <table className="w-full text-sm">
                        <thead className="bg-surface-elevated sticky top-0">
                            <tr>
                                <th className={`px-3 py-2 text-left font-semibold text-text-secondary uppercase`}>CheckId</th>
                                <th className={`px-3 py-2 text-left font-semibold text-text-secondary uppercase`}>Check Name</th>
                                <th className={`px-3 py-2 text-left font-semibold text-text-secondary uppercase`}>Category</th>
                                <th className={`px-3 py-2 text-left font-semibold text-text-secondary uppercase`}>Severity</th>
                            </tr>
                        </thead>
                        <tbody>
                            {filtered.map((f, i) => (
                                <tr key={i} className="border-t border-border-light hover:bg-bg-hover">
                                    <td className={`px-3 ${cellPad} font-mono text-text-primary`}>{f.CheckId}</td>
                                    <td className={`px-3 ${cellPad} text-text-primary`}>{f.CheckName}</td>
                                    <td className={`px-3 ${cellPad} text-text-secondary`}>{f.Category}</td>
                                    <td className={`px-3 ${cellPad} font-semibold ${
                                        f.Severity === 'Critical' ? 'text-critical' : 
                                        f.Severity === 'High' ? 'text-accent-orange' : 
                                        f.Severity === 'Medium' ? 'text-yellow-500' : 'text-blue-400'
                                    }`}>{f.Severity}</td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            )}
        </div>
    );
};

// --- Main Page Component ---
export default function Reports() {
    const queryClient = useQueryClient();
    const { tableDensity } = useSettings();
    const cellPad = tableDensity === 'compact' ? 'py-2' : tableDensity === 'spacious' ? 'py-5' : 'py-3.5';

    // Filters State
    const [showFilters, setShowFilters] = useState(false);
    const [filters, setFilters] = useState({
        search: '',
        engine: 'All',
        riskBand: 'All',
        dateStart: '',
        dateEnd: ''
    });

    // Selection & Expansion State
    const [selectedScans, setSelectedScans] = useState<Set<string>>(new Set());
    const [expandedScan, setExpandedScan] = useState<string | null>(null);

    // Fetch Summaries
    const { data: scans, isLoading } = useQuery({
        queryKey: ['reports-scans'],
        queryFn: async () => (await api.get('/reports/scans')).data as ReportSummary[]
    });

    // Mutations
    const deleteMutation = useMutation({
        mutationFn: async (scanIds: string[]) => (await api.delete('/reports/scans', { data: { scanIds } })).data,
        onSuccess: (data) => {
            queryClient.invalidateQueries({ queryKey: ['reports-scans'] });
            setSelectedScans(new Set());
            alert(data.message);
        }
    });

    const exportMutation = useMutation({
        mutationFn: async ({ scanIds, format }: { scanIds: string[]; format: string }) => {
            const res = await api.post('/reports/export', { scanIds, format }, { responseType: 'blob' });
            return res.data as Blob;
        },
        onSuccess: (blob) => {
            downloadBlob(blob, `adsuite-export-${Date.now()}.zip`);
        },
        onError: () => {
            alert('Export failed. Ensure you are signed in and scans are still available.');
        }
    });

    // Derived State
    const filteredScans = useMemo(() => {
        if (!scans) return [];
        return scans.filter(s => {
            if (filters.engine !== 'All' && s.engine !== filters.engine) return false;
            if (filters.riskBand !== 'All' && s.globalRiskBand?.toUpperCase() !== filters.riskBand.toUpperCase()) return false;
            
            if (filters.dateStart || filters.dateEnd) {
                const scanDate = new Date(s.timestamp).getTime();
                if (filters.dateStart && scanDate < new Date(filters.dateStart).getTime()) return false;
                if (filters.dateEnd && scanDate > new Date(filters.dateEnd).setHours(23, 59, 59, 999)) return false;
            }

            if (filters.search) {
                const q = filters.search.toLowerCase();
                return s.name.toLowerCase().includes(q) || s.id.toLowerCase().includes(q);
            }
            return true;
        });
    }, [scans, filters]);

    const handleSelectAll = () => {
        if (selectedScans.size === filteredScans.length) {
            setSelectedScans(new Set());
        } else {
            setSelectedScans(new Set(filteredScans.map(s => s.id)));
        }
    };

    const toggleSelection = (id: string) => {
        const next = new Set(selectedScans);
        if (next.has(id)) next.delete(id);
        else next.add(id);
        setSelectedScans(next);
    };

    if (isLoading) return <div className="p-8 text-text-secondary">Loading reports...</div>;

    return (
        <div className="max-w-7xl mx-auto space-y-6 pb-12">
            {/* Header */}
            <div className="flex items-end justify-between">
                <div>
                    <h1 className="text-3xl font-semibold text-text-primary mb-2 flex items-center gap-3">
                        <FileText className="text-accent-orange" size={28} /> Reports
                    </h1>
                    <p className="text-text-secondary">View and export detailed scan results and historical analysis.</p>
                </div>
            </div>

            {/* Filter Controls Toggle */}
            <div className="flex items-center justify-between bg-surface-elevated border border-border-light rounded-xl px-5 py-3">
                <button 
                    onClick={() => setShowFilters(!showFilters)}
                    className="flex items-center gap-2 text-text-primary font-medium hover:text-accent-orange transition-colors"
                >
                    <Filter size={18} /> Filters {showFilters ? <ChevronUp size={16}/> : <ChevronDown size={16}/>}
                </button>
                <div className="flex gap-3">
                    <div className="relative">
                        <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-text-tertiary" />
                        <input 
                            type="text" placeholder="Search report name..."
                            value={filters.search} onChange={e => setFilters({...filters, search: e.target.value})}
                            className="bg-bg-tertiary border border-border-medium rounded-lg pl-9 pr-4 py-1.5 text-sm text-text-primary focus:border-accent-orange outline-none w-64"
                        />
                    </div>
                </div>
            </div>

            {/* Filter Panel (Animated via CSS transition logic) */}
            {showFilters && (
                <div className="bg-surface-elevated border border-border-light rounded-xl p-5 animate-in slide-in-from-top-2 fade-in duration-200">
                    <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
                        <div className="col-span-1 md:col-span-2">
                            <label className="block text-sm font-medium text-text-secondary mb-2">Date Range</label>
                            <div className="flex items-center gap-2">
                                <input 
                                    type="date"
                                    value={filters.dateStart} onChange={e => setFilters({...filters, dateStart: e.target.value})}
                                    className="flex-1 bg-bg-tertiary border border-border-medium rounded-lg px-3 py-2 text-sm text-text-primary outline-none focus:border-accent-orange"
                                />
                                <span className="text-text-secondary">to</span>
                                <input 
                                    type="date"
                                    value={filters.dateEnd} onChange={e => setFilters({...filters, dateEnd: e.target.value})}
                                    className="flex-1 bg-bg-tertiary border border-border-medium rounded-lg px-3 py-2 text-sm text-text-primary outline-none focus:border-accent-orange"
                                />
                            </div>
                        </div>
                        <div>
                            <label className="block text-sm font-medium text-text-secondary mb-2">Engine</label>
                            <select 
                                value={filters.engine} onChange={e => setFilters({...filters, engine: e.target.value})}
                                className="w-full bg-bg-tertiary border border-border-medium rounded-lg px-3 py-2 text-sm text-text-primary outline-none"
                            >
                                <option value="All">All Engines</option>
                                <option value="ADSI">ADSI</option>
                                <option value="Unknown">Unknown</option>
                            </select>
                        </div>
                        <div>
                            <label className="block text-sm font-medium text-text-secondary mb-2">Global Risk Band</label>
                            <select 
                                value={filters.riskBand} onChange={e => setFilters({...filters, riskBand: e.target.value})}
                                className="w-full bg-bg-tertiary border border-border-medium rounded-lg px-3 py-2 text-sm text-text-primary outline-none"
                            >
                                <option value="All">All Risks</option>
                                <option value="Critical">Critical</option>
                                <option value="High">High</option>
                                <option value="Medium">Medium</option>
                                <option value="Low">Low</option>
                            </select>
                        </div>
                    </div>
                </div>
            )}

            {/* Bulk Actions Toolbar */}
            {selectedScans.size > 0 && (
                <div className="flex items-center justify-between bg-accent-orange-light/20 border border-accent-orange/30 rounded-xl px-5 py-3 animate-in fade-in">
                    <div className="text-accent-orange font-medium flex items-center gap-2">
                        <CheckSquare size={18} /> {selectedScans.size} selected
                    </div>
                    <div className="flex gap-3">
                        <button 
                            onClick={() => exportMutation.mutate({ scanIds: Array.from(selectedScans), format: 'json' })}
                            className="flex items-center gap-2 bg-surface border border-border-medium hover:bg-bg-hover text-text-primary px-4 py-1.5 rounded-lg text-sm font-medium transition-colors"
                        >
                            <Download size={16} /> Export JSON
                        </button>
                        <button 
                            onClick={() => exportMutation.mutate({ scanIds: Array.from(selectedScans), format: 'csv' })}
                            className="flex items-center gap-2 bg-surface border border-border-medium hover:bg-bg-hover text-text-primary px-4 py-1.5 rounded-lg text-sm font-medium transition-colors"
                        >
                            <Download size={16} /> Export CSV
                        </button>
                        <div className="w-px h-6 bg-border-medium mx-1 self-center" />
                        <button 
                            onClick={() => {
                                if (confirm('Are you sure you want to delete the selected scans?')) {
                                    deleteMutation.mutate(Array.from(selectedScans));
                                }
                            }}
                            className="flex items-center gap-2 bg-critical/10 hover:bg-critical/20 text-critical px-4 py-1.5 rounded-lg text-sm font-medium transition-colors"
                        >
                            <Trash2 size={16} /> Delete
                        </button>
                    </div>
                </div>
            )}

            {/* Scans Table */}
            {filteredScans.length === 0 ? (
                <EmptyState />
            ) : (
                <div className="bg-surface-elevated border border-border-light rounded-xl overflow-x-auto">
                    <table className="w-full text-sm">
                        <thead>
                            <tr className="bg-bg-tertiary border-b border-border-light">
                                <th className="px-4 py-3 text-left w-12">
                                    <button onClick={handleSelectAll} className="text-text-secondary hover:text-accent-orange">
                                        {selectedScans.size === filteredScans.length ? <CheckSquare size={18} /> : <Square size={18} />}
                                    </button>
                                </th>
                                <th className="px-4 py-3 text-left font-semibold text-text-secondary uppercase">Report Name</th>
                                <th className="px-4 py-3 text-left font-semibold text-text-secondary uppercase">Status</th>
                                <th className="px-4 py-3 text-left font-semibold text-text-secondary uppercase">Risk</th>
                                <th className="px-4 py-3 text-left font-semibold text-text-secondary uppercase">Findings</th>
                                <th className="px-4 py-3 text-left font-semibold text-text-secondary uppercase">Timestamp</th>
                            </tr>
                        </thead>
                        <tbody>
                            {filteredScans.map(scan => {
                                const isSelected = selectedScans.has(scan.id);
                                const isExpanded = expandedScan === scan.id;

                                return (
                                    <React.Fragment key={scan.id}>
                                        <tr className={`border-b border-border-light hover:bg-bg-hover transition-colors ${isSelected ? 'bg-accent-orange/5' : ''}`}>
                                            <td className={`px-4 ${cellPad}`}>
                                                <button onClick={() => toggleSelection(scan.id)} className={`${isSelected ? 'text-accent-orange' : 'text-text-tertiary hover:text-text-secondary'}`}>
                                                    {isSelected ? <CheckSquare size={18} /> : <Square size={18} />}
                                                </button>
                                            </td>
                                            <td className={`px-4 ${cellPad}`}>
                                                <button 
                                                    onClick={() => setExpandedScan(isExpanded ? null : scan.id)}
                                                    className="flex items-center gap-2 font-medium text-text-primary hover:text-accent-orange transition-colors text-left"
                                                >
                                                    {isExpanded ? <ChevronDown size={16} className="text-text-tertiary" /> : <ChevronRight size={16} className="text-text-tertiary" />}
                                                    {scan.name}
                                                </button>
                                            </td>
                                            <td className={`px-4 ${cellPad}`}>
                                                <span className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium ${
                                                    scan.status === 'Complete' ? 'bg-green-500/10 text-green-500 border border-green-500/20' : 
                                                    scan.status === 'Warning' ? 'bg-yellow-500/10 text-yellow-500 border border-yellow-500/20' : 
                                                    'bg-critical/10 text-critical border border-critical/20'
                                                }`}>
                                                    {scan.status === 'Complete' ? <Shield size={12} /> : scan.status === 'Warning' ? <FileWarning size={12} /> : <AlertCircle size={12} />}
                                                    {scan.status}
                                                </span>
                                            </td>
                                            <td className={`px-4 ${cellPad} font-semibold ${
                                                scan.globalRiskBand?.toUpperCase() === 'CRITICAL' ? 'text-critical' :
                                                scan.globalRiskBand?.toUpperCase() === 'HIGH' ? 'text-accent-orange' :
                                                scan.globalRiskBand?.toUpperCase() === 'MEDIUM' ? 'text-yellow-500' : 'text-blue-400'
                                            }`}>
                                                {scan.globalRiskBand}
                                            </td>
                                            <td className={`px-4 ${cellPad} text-text-secondary font-mono`}>{scan.totalFindings}</td>
                                            <td className={`px-4 ${cellPad} text-text-secondary flex items-center gap-2`}>
                                                <Clock size={14} /> {new Date(scan.timestamp).toLocaleString()}
                                            </td>
                                        </tr>
                                        {/* Expandable Preview */}
                                        {isExpanded && (
                                            <tr>
                                                <td colSpan={6} className="p-0">
                                                    <FindingsPreview scanId={scan.id} />
                                                </td>
                                            </tr>
                                        )}
                                    </React.Fragment>
                                );
                            })}
                        </tbody>
                    </table>
                </div>
            )}
        </div>
    );
}
