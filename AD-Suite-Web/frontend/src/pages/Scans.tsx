import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { Plus, Search, Shield, Clock, AlertCircle, Loader2 } from 'lucide-react';
import api from '../lib/api';

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

    const { data: scans, isLoading, isError } = useQuery({
        queryKey: ['scans-list'],
        queryFn: async () => (await api.get('/scans')).data as ScanSummary[]
    });

    const filtered = useMemo(() => {
        if (!scans) return [];
        if (!search.trim()) return scans;
        const q = search.toLowerCase();
        return scans.filter(
            (s) => s.name.toLowerCase().includes(q) || s.id.toLowerCase().includes(q)
        );
    }, [scans, search]);

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

            {!isLoading && !isError && filtered.length > 0 && (
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
