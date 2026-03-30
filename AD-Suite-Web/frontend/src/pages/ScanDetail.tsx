import { Link, useParams } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { ArrowLeft, Loader2, Download, FileJson } from 'lucide-react';
import api from '../lib/api';
import { downloadAuthenticated } from '../lib/download';

interface ScanDetailResponse {
    id: string;
    meta: Record<string, unknown>;
    aggregate: Record<string, unknown>;
    results: unknown[];
    byCategory?: unknown;
}

export default function ScanDetail() {
    const { id } = useParams<{ id: string }>();
    const scanId = id ? decodeURIComponent(id) : '';

    const { data, isLoading, isError, error } = useQuery({
        queryKey: ['scan-detail', scanId],
        queryFn: async () => (await api.get(`/scans/${encodeURIComponent(scanId)}`)).data as ScanDetailResponse,
        enabled: Boolean(scanId)
    });

    const handleExport = async (format: 'json' | 'csv') => {
        try {
            await downloadAuthenticated(
                `scans/${encodeURIComponent(scanId)}/export/${format}`,
                `AD_Suite_Scan_${scanId}.${format}`
            );
        } catch (e) {
            console.error(e);
        }
    };

    if (!scanId) {
        return <p className="text-text-secondary">Invalid scan id.</p>;
    }

    if (isLoading) {
        return (
            <div className="flex items-center gap-3 text-text-secondary py-16 justify-center">
                <Loader2 className="animate-spin" size={24} />
                Loading scan…
            </div>
        );
    }

    if (isError) {
        return (
            <div className="space-y-4">
                <Link
                    to="/scans"
                    className="inline-flex items-center gap-2 text-sm text-accent-orange hover:underline"
                >
                    <ArrowLeft size={16} /> Back to Scans
                </Link>
                <div className="p-6 rounded-xl border border-critical/30 bg-critical/5 text-critical text-sm">
                    {(error as Error)?.message || 'Scan not found or failed to load.'}
                </div>
            </div>
        );
    }

    const agg = data?.aggregate || {};
    const findingsCount = Array.isArray(data?.results) ? data.results.length : 0;

    return (
        <div className="space-y-8">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                <div>
                    <Link
                        to="/scans"
                        className="inline-flex items-center gap-2 text-sm text-accent-orange hover:underline mb-2"
                    >
                        <ArrowLeft size={16} /> Back to Scans
                    </Link>
                    <h1 className="text-3xl font-semibold text-text-primary">Scan details</h1>
                    <p className="text-text-secondary font-mono text-sm mt-1">{data?.id}</p>
                </div>
                <div className="flex flex-wrap gap-2">
                    <button
                        type="button"
                        onClick={() => handleExport('json')}
                        className="inline-flex items-center gap-2 px-4 py-2 rounded-lg bg-bg-tertiary border border-border-medium text-text-primary text-sm font-medium hover:bg-bg-hover"
                    >
                        <FileJson size={16} /> Export JSON
                    </button>
                    <button
                        type="button"
                        onClick={() => handleExport('csv')}
                        className="inline-flex items-center gap-2 px-4 py-2 rounded-lg bg-bg-tertiary border border-border-medium text-text-primary text-sm font-medium hover:bg-bg-hover"
                    >
                        <Download size={16} /> Export CSV
                    </button>
                </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div className="bg-surface-elevated border border-border-light rounded-xl p-5">
                    <div className="text-xs font-medium text-text-secondary uppercase tracking-wide mb-1">
                        Global risk
                    </div>
                    <div className="text-xl font-semibold text-text-primary">
                        {String(agg.globalRiskBand ?? agg.GlobalRiskBand ?? '—')}
                    </div>
                </div>
                <div className="bg-surface-elevated border border-border-light rounded-xl p-5">
                    <div className="text-xs font-medium text-text-secondary uppercase tracking-wide mb-1">
                        Findings (rows)
                    </div>
                    <div className="text-xl font-semibold text-text-primary">{findingsCount}</div>
                </div>
                <div className="bg-surface-elevated border border-border-light rounded-xl p-5">
                    <div className="text-xs font-medium text-text-secondary uppercase tracking-wide mb-1">
                        Total findings (aggregate)
                    </div>
                    <div className="text-xl font-semibold text-text-primary">
                        {String(agg.totalFindings ?? agg.TotalFindings ?? '—')}
                    </div>
                </div>
            </div>

            <div className="bg-surface-elevated border border-border-light rounded-xl p-6">
                <h2 className="text-lg font-semibold text-text-primary mb-4">Metadata</h2>
                <pre className="text-xs font-mono text-text-secondary bg-bg-tertiary border border-border-medium rounded-lg p-4 overflow-auto max-h-64">
                    {JSON.stringify(data?.meta ?? {}, null, 2)}
                </pre>
            </div>

            <div className="bg-surface-elevated border border-border-light rounded-xl p-6">
                <h2 className="text-lg font-semibold text-text-primary mb-4">Aggregate</h2>
                <pre className="text-xs font-mono text-text-secondary bg-bg-tertiary border border-border-medium rounded-lg p-4 overflow-auto max-h-64">
                    {JSON.stringify(agg, null, 2)}
                </pre>
            </div>
        </div>
    );
}
