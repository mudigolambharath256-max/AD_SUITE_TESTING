import { useState, useEffect, useRef, useMemo } from 'react';
import { useQuery, useMutation } from '@tanstack/react-query';
import mermaid from 'mermaid';
import {
    Network,
    Settings,
    AlertCircle,
    FileText,
    Play,
    Loader2,
    CheckCircle2,
    Bot,
    Upload,
    Maximize2,
    Minimize2
} from 'lucide-react';
import api from '../lib/api';
import {
    buildTokenMaps,
    deepRedact,
    detokenizeMermaidChart,
    detokenizeText,
    tokenMapEntries,
    tokenizeFinding,
    type TokenMaps
} from '../lib/llmTokenize';
import AttackPathKillChainGraph from '../components/AttackPathKillChainGraph';
import { flattenFindingRows, canonicalSeverityForFilter } from '../lib/extractEntityGraph';

// --- Types ---
interface ReportSummary {
    id: string;
    name: string;
    totalFindings: number;
}

interface Finding {
    CheckId: string;
    CheckName: string;
    Severity: string;
    [key: string]: any;
}

interface AnalysisResponse {
    executiveSummary: null | {
        riskLevel: 'Low' | 'Medium' | 'High' | 'Critical' | string;
        mostCriticalFindingId: string;
        text: string;
    };
    killChains: Array<{
        title?: string;
        chain?: string;
        endTier0Objective?: string;
        steps?: Array<{ findingId: string; attackerAction: string }>;
    }>;
    chokePoints: Array<{
        entity: string;
        whyHighLeverage?: string;
        relatedFindingIds?: string[];
    }>;
    immediateActions: Array<{
        action: string;
        targets?: string[];
        relatedFindingIds?: string[];
        expectedImpact?: string;
    }>;
    mermaidChart: string;
    metadata: {
        provider: string;
        duration: string;
        findingsCount: number;
        rawInputCount?: number;
        distinctGroups?: number;
        groupsCollapsed?: number;
        payloadRows?: number;
        approxChars?: number;
        truncatedToBudget?: boolean;
        redactionApplied?: boolean;
    };
}

// --- Mermaid Component ---
const MermaidGraph = ({ chart, className = '' }: { chart: string; className?: string }) => {
    const containerRef = useRef<HTMLDivElement>(null);
    const [svgCode, setSvgCode] = useState<string>('');
    const [error, setError] = useState<string>('');

    useEffect(() => {
        if (!chart) return;
        mermaid.initialize({ startOnLoad: false, theme: 'dark' });
        
        const renderChart = async () => {
            try {
                // Strip markdown formatting if the LLM hallucinated it
                let cleanChart = chart.replace(/```mermaid/gi, '').replace(/```/g, '').trim();
                const { svg } = await mermaid.render('mermaid-svg-' + Date.now(), cleanChart);
                setSvgCode(svg);
                setError('');
            } catch (err: any) {
                console.error("Mermaid Render Error:", err);
                setError("Failed to render graph. The AI may have generated invalid syntax.");
            }
        };
        renderChart();
    }, [chart]);

    if (error) {
        return <div className="p-4 border border-critical/30 bg-critical/10 text-critical text-sm rounded-lg">{error}</div>;
    }

    if (!chart) return null;

    return (
        <div 
            ref={containerRef} 
            className={`w-full overflow-auto flex justify-center items-start p-4 bg-bg-tertiary rounded-lg border border-border-medium ${className}`}
            dangerouslySetInnerHTML={{ __html: svgCode }}
        />
    );
};

// --- Main Component ---
export default function AttackPath() {
    // LLM Config State
    const [provider, setProvider] = useState<string>('ollama');
    const [model, setModel] = useState<string>('llama3');
    const [apiKey, setApiKey] = useState<string>('');

    // Data Selection State
    const [selectedScanId, setSelectedScanId] = useState<string>('');
    const [localFindings, setLocalFindings] = useState<Finding[]>([]);
    const [selectedSeverities, setSelectedSeverities] = useState<Set<string>>(new Set(['Critical', 'High']));
    const fileInputRef = useRef<HTMLInputElement>(null);
    const [tokenEntries, setTokenEntries] = useState<Array<{ token: string; real: string; type: string }>>([]);
    const [tokenSearch, setTokenSearch] = useState<string>('');
    const [mermaidLabelMode, setMermaidLabelMode] = useState<'tokens' | 'real'>('tokens');
    const [chartTokenMaps, setChartTokenMaps] = useState<TokenMaps | null>(null);
    const [isGraphFullscreen, setIsGraphFullscreen] = useState(false);
    const graphPanelRef = useRef<HTMLDivElement>(null);
    const [visualGraphTab, setVisualGraphTab] = useState<'mermaid' | 'd3'>('mermaid');

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

    // Fetch Scans for Dropdown
    const { data: scans } = useQuery({
        queryKey: ['attack-path-scans'],
        queryFn: async () => (await api.get('/reports/scans')).data as ReportSummary[]
    });

    // Fetch Findings for selected scan
    const { data: activeFindings } = useQuery({
        queryKey: ['attack-path-findings', selectedScanId],
        queryFn: async () => (await api.get('/reports/scans/' + selectedScanId + '/findings')).data.findings as Finding[],
        enabled: !!selectedScanId
    });

    const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        if (!file) return;

        const reader = new FileReader();
        reader.onload = (event) => {
            try {
                const doc = JSON.parse(event.target?.result as string);
                const results = doc.results ?? doc.Results ?? [];
                
                if (results.length === 0) {
                    alert("No findings found in the uploaded file.");
                }
                
                setLocalFindings(results);
                setSelectedScanId(''); // Clear server selection when local file is used
            } catch (err) {
                console.error("Failed to parse file:", err);
                alert("Invalid JSON file uploaded.");
            }
        };
        reader.readAsText(file);
        
        // Reset input logic
        if (fileInputRef.current) fileInputRef.current.value = '';
    };

    /** Flatten nested Findings[] into rows (matches scan file shape). Severity filter is case-insensitive. */
    const payloadFindings = useMemo(() => {
        const sourceFindings = localFindings.length > 0 ? localFindings : (activeFindings || []);
        const rows = flattenFindingRows(sourceFindings, { includeParentWhenNoNestedFindings: true });
        return rows.filter((f) => {
            const bucket = canonicalSeverityForFilter(f.Severity ?? f.severity);
            return selectedSeverities.has(bucket);
        });
    }, [activeFindings, localFindings, selectedSeverities]);

    const toggleSeverity = (sev: string) => {
        const next = new Set(selectedSeverities);
        if (next.has(sev)) next.delete(sev);
        else next.add(sev);
        setSelectedSeverities(next);
    };

    // Analyze Mutation
    const analyzeMutation = useMutation({
        mutationFn: async () => {
            const normalizedModel =
                provider === 'openai'
                    ? model.trim().replace(/\s+/g, '-')
                    : model.trim();

            // Browser-only gateway: build token map and tokenize + redact before sending.
            const rawFindingObjs = payloadFindings.map((f) => ({ ...f })) as Array<Record<string, unknown>>;
            const maps = buildTokenMaps(rawFindingObjs);
            const entries = tokenMapEntries(maps).map((e) => ({ token: e.token, real: e.real, type: e.type }));
            setTokenEntries(entries);

            const tokenized = rawFindingObjs.map((f) => deepRedact(tokenizeFinding(f, maps)));

            const res = await api.post('/attack-path/analyze', {
                findings: tokenized.map((f: any) => ({
                    ...f,
                    CheckId: f.CheckId,
                    CheckName: f.CheckName,
                    Severity: f.Severity || f.severity,
                    Category: f.Category || f.category,
                    Description: f.Description || f.Name,
                    Impact: f.Impact || f.RiskData || f.Message
                })),
                llmProvider: provider,
                model: normalizedModel,
                apiKey: apiKey || undefined
            });

            // Detokenize the response for display, but keep token map visible for auditing/debug.
            const data = res.data as AnalysisResponse;
            const tokenToEntry: any = {};
            const realToToken: any = {};
            for (const e of entries) {
                tokenToEntry[e.token] = e;
                realToToken[e.real] = e.token;
            }
            const mapsForDetok: TokenMaps = { tokenToEntry, realToToken };
            setChartTokenMaps(mapsForDetok);
            setMermaidLabelMode('tokens');

            if (data.executiveSummary?.text) {
                data.executiveSummary.text = detokenizeText(data.executiveSummary.text, mapsForDetok);
            }
            if (data.executiveSummary?.mostCriticalFindingId) {
                data.executiveSummary.mostCriticalFindingId = detokenizeText(
                    data.executiveSummary.mostCriticalFindingId,
                    mapsForDetok
                );
            }
            if (Array.isArray(data.killChains)) {
                data.killChains = data.killChains.map((kc: any) => ({
                    ...kc,
                    title: kc.title ? detokenizeText(kc.title, mapsForDetok) : kc.title,
                    chain: kc.chain ? detokenizeText(kc.chain, mapsForDetok) : kc.chain,
                    steps: Array.isArray(kc.steps)
                        ? kc.steps.map((s: any) => ({
                              ...s,
                              findingId: detokenizeText(String(s.findingId || ''), mapsForDetok),
                              attackerAction: detokenizeText(String(s.attackerAction || ''), mapsForDetok)
                          }))
                        : kc.steps
                }));
            }
            if (Array.isArray(data.chokePoints)) {
                data.chokePoints = data.chokePoints.map((cp: any) => ({
                    ...cp,
                    entity: detokenizeText(String(cp.entity || ''), mapsForDetok),
                    whyHighLeverage: cp.whyHighLeverage
                        ? detokenizeText(String(cp.whyHighLeverage), mapsForDetok)
                        : cp.whyHighLeverage,
                    relatedFindingIds: Array.isArray(cp.relatedFindingIds)
                        ? cp.relatedFindingIds.map((x: any) => detokenizeText(String(x), mapsForDetok))
                        : cp.relatedFindingIds
                }));
            }
            if (Array.isArray(data.immediateActions)) {
                data.immediateActions = data.immediateActions.map((a: any) => ({
                    ...a,
                    action: detokenizeText(String(a.action || ''), mapsForDetok),
                    expectedImpact: a.expectedImpact
                        ? detokenizeText(String(a.expectedImpact), mapsForDetok)
                        : a.expectedImpact,
                    targets: Array.isArray(a.targets)
                        ? a.targets.map((x: any) => detokenizeText(String(x), mapsForDetok))
                        : a.targets,
                    relatedFindingIds: Array.isArray(a.relatedFindingIds)
                        ? a.relatedFindingIds.map((x: any) => detokenizeText(String(x), mapsForDetok))
                        : a.relatedFindingIds
                }));
            }
            // Keep Mermaid nodes as tokens (privacy + render safety). Use the mapping panel to resolve tokens.
            return data;
        }
    });

    /** Prefer structured path tab when no Mermaid diagram but kill chains exist */
    useEffect(() => {
        const d = analyzeMutation.data;
        if (!d) return;
        const hasM = Boolean(d.mermaidChart?.trim());
        const hasK = (d.killChains ?? []).some((c) => (c.steps?.length ?? 0) > 0);
        if (hasK && !hasM) setVisualGraphTab('d3');
        else if (hasM) setVisualGraphTab('mermaid');
    }, [analyzeMutation.data]);

    const hasStructuredKillChains = useMemo(() => {
        const kc = analyzeMutation.data?.killChains;
        if (!kc?.length) return false;
        return kc.some((c) => (c.steps?.length ?? 0) > 0);
    }, [analyzeMutation.data?.killChains]);

    const mermaidDisplayChart = useMemo(() => {
        const raw = analyzeMutation.data?.mermaidChart;
        if (!raw) return '';
        if (mermaidLabelMode === 'real' && chartTokenMaps) {
            try {
                return detokenizeMermaidChart(raw, chartTokenMaps);
            } catch {
                return raw;
            }
        }
        return raw;
    }, [analyzeMutation.data?.mermaidChart, mermaidLabelMode, chartTokenMaps]);

    return (
        <div className="max-w-7xl mx-auto space-y-6 pb-12">
            {/* Header */}
            <div>
                <h1 className="text-3xl font-semibold text-text-primary mb-2 flex items-center gap-3">
                    <Network className="text-accent-orange" size={28} /> Attack Path Analysis
                </h1>
                <p className="text-text-secondary">AI-powered attack path identification and narrative generation.</p>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
                
                {/* Configuration Panel */}
                <div className="lg:col-span-4 space-y-6">
                    <div className="bg-surface-elevated border border-border-light rounded-xl p-5 shadow-sm">
                        <h2 className="text-lg font-medium text-text-primary flex items-center gap-2 mb-4">
                            <Settings size={20} className="text-text-tertiary" /> Configuration
                        </h2>

                        {/* Data Source */}
                        <div className="space-y-4 mb-6">
                            <div>
                                <label className="block text-sm font-medium text-text-secondary mb-1">Data Source</label>
                                <div className="flex gap-2">
                                    <select 
                                        value={selectedScanId} onChange={e => {
                                            setSelectedScanId(e.target.value);
                                            setLocalFindings([]); // Clear local findings if server scan selected
                                        }}
                                        className="flex-1 bg-bg-tertiary border border-border-medium rounded-lg px-3 py-2 text-sm text-text-primary outline-none focus:border-accent-orange"
                                    >
                                        <option value="">{localFindings.length > 0 ? 'Using Local File...' : 'Select a Scan...'}</option>
                                        {scans?.map(s => (
                                            <option key={s.id} value={s.id}>{s.name} ({s.totalFindings} findings)</option>
                                        ))}
                                    </select>
                                    
                                    <input 
                                        type="file" 
                                        accept=".json" 
                                        ref={fileInputRef} 
                                        className="hidden" 
                                        onChange={handleFileUpload} 
                                    />
                                    <button 
                                        type="button" 
                                        onClick={() => fileInputRef.current?.click()} 
                                        className="px-3 py-2 bg-bg-tertiary border border-border-medium rounded-lg hover:bg-surface-elevated text-text-secondary transition-colors"
                                        title="Upload local scan file"
                                    >
                                        <Upload size={18} />
                                    </button>
                                </div>
                            </div>

                            {/* Severity Filter */}
                            <div>
                                <label className="block text-sm font-medium text-text-secondary mb-2">Severity Included in Prompt</label>
                                <div className="flex flex-wrap gap-2">
                                    {['Critical', 'High', 'Medium', 'Low'].map(sev => (
                                        <button 
                                            key={sev}
                                            onClick={() => toggleSeverity(sev)}
                                            className={"px-3 py-1 text-xs font-medium rounded-full border transition-colors " + (
                                                selectedSeverities.has(sev) 
                                                ? 'bg-accent-orange-light/20 border-accent-orange/40 text-accent-orange'
                                                : 'bg-bg-tertiary border-border-medium text-text-tertiary hover:border-text-tertiary'
                                            )}
                                        >
                                            {sev}
                                        </button>
                                    ))}
                                </div>
                            </div>
                        </div>

                        <div className="h-px bg-border-light my-6" />

                        {/* LLM Settings */}
                        <div className="space-y-4 mb-6">
                            <div>
                                <label className="block text-sm font-medium text-text-secondary mb-1">Provider</label>
                                <select 
                                    value={provider} onChange={e => {
                                        setProvider(e.target.value);
                                        setModel(e.target.value === 'ollama' ? 'llama3' : e.target.value === 'openai' ? 'gpt-4o-mini' : 'claude-3-haiku-20240307');
                                    }}
                                    className="w-full bg-bg-tertiary border border-border-medium rounded-lg px-3 py-2 text-sm text-text-primary outline-none focus:border-accent-orange"
                                >
                                    <option value="ollama">Ollama (Local)</option>
                                    <option value="openai">OpenAI</option>
                                    <option value="anthropic">Anthropic</option>
                                </select>
                            </div>
                            <div>
                                <label className="block text-sm font-medium text-text-secondary mb-1">Model ID</label>
                                <input 
                                    type="text" value={model} onChange={e => setModel(e.target.value)}
                                    className="w-full bg-bg-tertiary border border-border-medium rounded-lg px-3 py-2 text-sm text-text-primary outline-none focus:border-accent-orange"
                                />
                            </div>
                            {provider !== 'ollama' && (
                                <div>
                                    <label className="block text-sm font-medium text-text-secondary mb-1">API Key</label>
                                    <input 
                                        type="password" value={apiKey} onChange={e => setApiKey(e.target.value)} placeholder="sk-..."
                                        className="w-full bg-bg-tertiary border border-border-medium rounded-lg px-3 py-2 text-sm text-text-primary outline-none focus:border-accent-orange"
                                    />
                                </div>
                            )}
                        </div>

                        {/* Process Button */}
                        <button 
                            onClick={() => analyzeMutation.mutate()}
                            disabled={!(selectedScanId || localFindings.length > 0) || payloadFindings.length === 0 || analyzeMutation.isPending}
                            className="w-full flex items-center justify-center gap-2 bg-accent-orange hover:bg-opacity-90 disabled:opacity-50 disabled:cursor-not-allowed text-white px-4 py-2.5 rounded-lg text-sm font-medium transition-all"
                        >
                            {analyzeMutation.isPending ? (
                                <><Loader2 size={18} className="animate-spin" /> Analyzing...</>
                            ) : (
                                <><Play size={18} fill="currentColor" /> Generate Attack Path</>
                            )}
                        </button>
                        
                        {(selectedScanId || localFindings.length > 0) && (
                            <p className="text-center text-xs text-text-tertiary mt-3">
                                {payloadFindings.length} finding row{payloadFindings.length === 1 ? '' : 's'} after
                                severity filter — enable Critical/High/Medium/Low if this is 0.
                            </p>
                        )}

                        {/* Token map panel (browser-only safety gateway) */}
                        {tokenEntries.length > 0 && (
                            <div className="mt-4 p-3 rounded-lg bg-bg-tertiary border border-border-medium text-xs text-text-secondary space-y-2">
                                <div className="flex items-center justify-between gap-2">
                                    <div className="font-medium text-text-primary">Token map (shown: token = real)</div>
                                    <div className="text-text-tertiary">{tokenEntries.length} entries</div>
                                </div>
                                <input
                                    type="text"
                                    value={tokenSearch}
                                    onChange={(e) => setTokenSearch(e.target.value)}
                                    placeholder="Search token or real value…"
                                    className="w-full bg-surface-elevated border border-border-medium rounded-lg px-3 py-2 text-xs text-text-primary outline-none focus:border-accent-orange"
                                />
                                <div className="max-h-40 overflow-auto border border-border-medium rounded-lg">
                                    <table className="w-full text-left">
                                        <thead className="sticky top-0 bg-bg-tertiary border-b border-border-medium">
                                            <tr>
                                                <th className="px-2 py-1 text-text-tertiary font-medium">Token</th>
                                                <th className="px-2 py-1 text-text-tertiary font-medium">Type</th>
                                                <th className="px-2 py-1 text-text-tertiary font-medium">Real</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            {tokenEntries
                                                .filter((e) => {
                                                    const q = tokenSearch.trim().toLowerCase();
                                                    if (!q) return true;
                                                    return (
                                                        e.token.toLowerCase().includes(q) ||
                                                        e.type.toLowerCase().includes(q) ||
                                                        e.real.toLowerCase().includes(q)
                                                    );
                                                })
                                                .slice(0, 200)
                                                .map((e) => (
                                                    <tr key={e.token} className="border-t border-border-light/40">
                                                        <td className="px-2 py-1 font-mono text-text-primary">{e.token}</td>
                                                        <td className="px-2 py-1 text-text-tertiary">{e.type}</td>
                                                        <td className="px-2 py-1 text-text-secondary">{e.real}</td>
                                                    </tr>
                                                ))}
                                        </tbody>
                                    </table>
                                </div>
                                <div className="flex gap-2">
                                    <button
                                        type="button"
                                        onClick={() =>
                                            navigator.clipboard.writeText(JSON.stringify(tokenEntries, null, 2))
                                        }
                                        className="px-3 py-1.5 bg-surface-elevated border border-border-medium rounded-lg hover:bg-bg-tertiary text-text-secondary transition-colors"
                                    >
                                        Copy mapping JSON
                                    </button>
                                </div>
                            </div>
                        )}

                        {analyzeMutation.data?.metadata.rawInputCount != null && (
                            <div className="mt-4 p-3 rounded-lg bg-bg-tertiary border border-border-medium text-xs text-text-secondary space-y-1">
                                <div className="font-medium text-text-primary">Payload sent to model</div>
                                <p>
                                    <span className="text-text-primary">{analyzeMutation.data.metadata.rawInputCount}</span>{' '}
                                    findings received →{' '}
                                    <span className="text-text-primary">
                                        {analyzeMutation.data.metadata.payloadRows ?? analyzeMutation.data.metadata.findingsCount}
                                    </span>{' '}
                                    sample rows in{' '}
                                    <span className="text-text-primary">{analyzeMutation.data.metadata.distinctGroups ?? '—'}</span>{' '}
                                    groups
                                    {typeof analyzeMutation.data.metadata.groupsCollapsed === 'number' &&
                                        analyzeMutation.data.metadata.groupsCollapsed > 0 && (
                                            <>
                                                {' '}
                                                ({analyzeMutation.data.metadata.groupsCollapsed} duplicate rows merged into groups)
                                            </>
                                        )}
                                    .
                                </p>
                                <p>
                                    ~{analyzeMutation.data.metadata.approxChars?.toLocaleString() ?? '—'} chars
                                    {analyzeMutation.data.metadata.truncatedToBudget && (
                                        <span className="text-accent-orange ml-1">(trimmed to budget)</span>
                                    )}
                                    {analyzeMutation.data.metadata.redactionApplied && (
                                        <span className="text-text-tertiary ml-1">· PII patterns redacted</span>
                                    )}
                                </p>
                            </div>
                        )}
                    </div>
                </div>

                {/* Main Results Panel */}
                <div className="lg:col-span-8 flex flex-col gap-6">
                    {/* Graph Panel */}
                    <div
                        ref={graphPanelRef}
                        className={`bg-surface-elevated border border-border-light rounded-xl p-5 shadow-sm min-h-[300px] ${
                            isGraphFullscreen ? 'min-h-screen flex flex-col rounded-none border-border-medium' : ''
                        }`}
                    >
                        <div className="flex flex-wrap items-center justify-between gap-3 mb-3">
                            <h2 className="text-lg font-medium text-text-primary flex items-center gap-2">
                                <Network size={20} className="text-accent-orange" /> Visual Graph
                            </h2>
                            <div className="flex flex-wrap items-center gap-2">
                                {analyzeMutation.data &&
                                (Boolean(analyzeMutation.data.mermaidChart?.trim()) || hasStructuredKillChains) ? (
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
                                ) : null}
                                {visualGraphTab === 'mermaid' &&
                                analyzeMutation.data?.mermaidChart &&
                                chartTokenMaps ? (
                                    <div className="flex items-center gap-2">
                                        <span className="text-xs text-text-tertiary">Diagram labels</span>
                                        <div className="inline-flex rounded-lg border border-border-medium overflow-hidden text-xs">
                                            <button
                                                type="button"
                                                onClick={() => setMermaidLabelMode('tokens')}
                                                className={`px-3 py-1.5 font-medium ${
                                                    mermaidLabelMode === 'tokens'
                                                        ? 'bg-accent-orange-light/20 text-accent-orange'
                                                        : 'bg-bg-tertiary text-text-secondary hover:bg-bg-hover'
                                                }`}
                                            >
                                                Tokens
                                            </button>
                                            <button
                                                type="button"
                                                onClick={() => setMermaidLabelMode('real')}
                                                className={`px-3 py-1.5 font-medium border-l border-border-medium ${
                                                    mermaidLabelMode === 'real'
                                                        ? 'bg-accent-orange-light/20 text-accent-orange'
                                                        : 'bg-bg-tertiary text-text-secondary hover:bg-bg-hover'
                                                }`}
                                            >
                                                Real names
                                            </button>
                                        </div>
                                    </div>
                                ) : null}
                            </div>
                        </div>

                        {analyzeMutation.data ? (
                            <div className="inline-flex rounded-lg border border-border-medium overflow-hidden text-xs mb-3">
                                <button
                                    type="button"
                                    onClick={() => setVisualGraphTab('mermaid')}
                                    className={`px-3 py-1.5 font-medium ${
                                        visualGraphTab === 'mermaid'
                                            ? 'bg-accent-orange-light/20 text-accent-orange'
                                            : 'bg-bg-tertiary text-text-secondary hover:bg-bg-hover'
                                    }`}
                                >
                                    LLM diagram
                                </button>
                                <button
                                    type="button"
                                    onClick={() => setVisualGraphTab('d3')}
                                    className={`px-3 py-1.5 font-medium border-l border-border-medium ${
                                        visualGraphTab === 'd3'
                                            ? 'bg-accent-orange-light/20 text-accent-orange'
                                            : 'bg-bg-tertiary text-text-secondary hover:bg-bg-hover'
                                    }`}
                                >
                                    Finding path
                                </button>
                            </div>
                        ) : null}

                        <p className="text-xs text-text-tertiary mb-3">
                            {visualGraphTab === 'mermaid' ? (
                                <>
                                    Mermaid diagram from the model (entity flow). Use Tokens / Real names for node
                                    labels. Finding IDs belong in kill-chain text below.
                                </>
                            ) : (
                                <>
                                    Deterministic layout from structured kill chains: finding IDs as nodes, actions on
                                    edges. Same data as the report, without relying on Mermaid syntax.
                                </>
                            )}
                        </p>

                        {!analyzeMutation.data ? (
                            <div className="h-48 flex flex-col items-center justify-center text-text-tertiary border-2 border-dashed border-border-medium rounded-lg">
                                <Bot size={32} className="mb-2" />
                                <p>Awaiting analysis execution.</p>
                            </div>
                        ) : visualGraphTab === 'mermaid' ? (
                            <div
                                className={
                                    isGraphFullscreen
                                        ? 'flex-1 min-h-0 flex flex-col overflow-auto'
                                        : ''
                                }
                            >
                                {analyzeMutation.data.mermaidChart?.trim() ? (
                                    <MermaidGraph
                                        key={mermaidLabelMode}
                                        chart={mermaidDisplayChart}
                                        className={isGraphFullscreen ? 'min-h-[min(85vh,1200px)]' : ''}
                                    />
                                ) : (
                                    <div className="p-4 bg-bg-tertiary border border-border-medium rounded-lg text-text-secondary text-sm">
                                        The AI did not return a valid Mermaid chart. Try the Finding path tab if kill
                                        chains are present.
                                    </div>
                                )}
                            </div>
                        ) : (
                            <div
                                className={
                                    isGraphFullscreen
                                        ? 'flex-1 min-h-0 flex flex-col overflow-auto'
                                        : ''
                                }
                            >
                                <AttackPathKillChainGraph
                                    killChains={analyzeMutation.data.killChains}
                                    isFullscreen={isGraphFullscreen}
                                />
                            </div>
                        )}
                    </div>

                    {/* Narrative Panel */}
                    <div className="bg-surface-elevated border border-border-light rounded-xl p-5 shadow-sm flex-1">
                        <div className="flex items-center justify-between mb-4 pb-4 border-b border-border-light">
                            <h2 className="text-lg font-medium text-text-primary flex items-center gap-2">
                                <FileText size={20} className="text-text-secondary" /> Attack Path Report
                            </h2>
                            {analyzeMutation.data && (
                                <div className="flex flex-wrap items-center gap-4 text-xs font-medium text-text-secondary">
                                    <span className="flex items-center gap-1"><CheckCircle2 size={14} className="text-green-500"/> {analyzeMutation.data.metadata.payloadRows ?? analyzeMutation.data.metadata.findingsCount} rows in prompt</span>
                                    <span className="bg-bg-tertiary px-2 py-1 rounded-md border border-border-medium">{analyzeMutation.data.metadata.provider.toUpperCase()}</span>
                                    <span className="bg-bg-tertiary px-2 py-1 rounded-md border border-border-medium">{analyzeMutation.data.metadata.duration} latency</span>
                                </div>
                            )}
                        </div>
                        
                        <div className="max-w-none text-text-secondary space-y-6">
                            {analyzeMutation.error ? (
                                <div className="p-4 border border-critical/30 bg-critical/10 text-critical rounded-lg flex items-start gap-3">
                                    <AlertCircle className="mt-0.5 shrink-0" size={18} />
                                    <div>
                                        <strong>Analysis Failed:</strong>
                                        <p className="mt-1">{analyzeMutation.error.message}</p>
                                    </div>
                                </div>
                            ) : analyzeMutation.data ? (
                                <>
                                    {/* Executive summary */}
                                    <div className="bg-bg-tertiary border border-border-medium rounded-lg p-4">
                                        <div className="text-xs uppercase tracking-wide text-text-tertiary">Executive summary</div>
                                        <div className="mt-2 flex flex-wrap items-center gap-2 text-sm">
                                            <span className="px-2 py-1 rounded-md border border-border-medium bg-surface-elevated text-text-primary">
                                                Risk: {analyzeMutation.data.executiveSummary?.riskLevel ?? '—'}
                                            </span>
                                            <span className="px-2 py-1 rounded-md border border-border-medium bg-surface-elevated text-text-primary">
                                                Most critical: {analyzeMutation.data.executiveSummary?.mostCriticalFindingId ?? '—'}
                                            </span>
                                        </div>
                                        <p className="mt-3 text-sm text-text-secondary">
                                            {analyzeMutation.data.executiveSummary?.text ?? 'No executive summary returned.'}
                                        </p>
                                    </div>

                                    {/* Kill chains */}
                                    <div>
                                        <div className="text-sm font-medium text-text-primary mb-2">Kill chains</div>
                                        {analyzeMutation.data.killChains?.length ? (
                                            <div className="space-y-3">
                                                {analyzeMutation.data.killChains.slice(0, 5).map((kc, idx) => (
                                                    <div key={idx} className="border border-border-medium rounded-lg p-4 bg-bg-tertiary">
                                                        <div className="flex flex-wrap items-center justify-between gap-2">
                                                            <div className="text-text-primary font-medium">
                                                                {kc.title || `Chain ${idx + 1}`}
                                                            </div>
                                                            {kc.endTier0Objective && (
                                                                <div className="text-xs px-2 py-1 rounded-md border border-border-medium bg-surface-elevated">
                                                                    Tier-0: {kc.endTier0Objective}
                                                                </div>
                                                            )}
                                                        </div>
                                                        {kc.chain && (
                                                            <div className="mt-2 text-sm text-text-secondary">
                                                                <span className="text-text-tertiary">Chain:</span> {kc.chain}
                                                            </div>
                                                        )}
                                                        {kc.steps?.length ? (
                                                            <ol className="mt-3 space-y-2 text-sm">
                                                                {kc.steps.map((s, sIdx) => (
                                                                    <li key={sIdx} className="flex gap-2">
                                                                        <span className="text-text-tertiary">{sIdx + 1}.</span>
                                                                        <span className="text-text-primary">{s.findingId}</span>
                                                                        <span className="text-text-secondary">— {s.attackerAction}</span>
                                                                    </li>
                                                                ))}
                                                            </ol>
                                                        ) : (
                                                            <div className="mt-3 text-sm text-text-tertiary">No steps returned.</div>
                                                        )}
                                                    </div>
                                                ))}
                                            </div>
                                        ) : (
                                            <div className="text-sm text-text-tertiary">No kill chains returned.</div>
                                        )}
                                    </div>

                                    {/* Choke points */}
                                    <div>
                                        <div className="text-sm font-medium text-text-primary mb-2">Choke points</div>
                                        {analyzeMutation.data.chokePoints?.length ? (
                                            <div className="space-y-2">
                                                {analyzeMutation.data.chokePoints.slice(0, 5).map((cp, idx) => (
                                                    <div key={idx} className="border border-border-medium rounded-lg p-3 bg-bg-tertiary">
                                                        <div className="text-text-primary font-medium">{cp.entity}</div>
                                                        {cp.whyHighLeverage && (
                                                            <div className="text-sm text-text-secondary mt-1">{cp.whyHighLeverage}</div>
                                                        )}
                                                        {cp.relatedFindingIds?.length ? (
                                                            <div className="text-xs text-text-tertiary mt-2">
                                                                Related: {cp.relatedFindingIds.join(', ')}
                                                            </div>
                                                        ) : null}
                                                    </div>
                                                ))}
                                            </div>
                                        ) : (
                                            <div className="text-sm text-text-tertiary">No choke points returned.</div>
                                        )}
                                    </div>

                                    {/* Immediate actions */}
                                    <div>
                                        <div className="text-sm font-medium text-text-primary mb-2">Immediate actions</div>
                                        {analyzeMutation.data.immediateActions?.length ? (
                                            <div className="space-y-2">
                                                {analyzeMutation.data.immediateActions.slice(0, 3).map((a, idx) => (
                                                    <div key={idx} className="border border-border-medium rounded-lg p-3 bg-bg-tertiary">
                                                        <div className="text-text-primary font-medium">{a.action}</div>
                                                        {a.expectedImpact && (
                                                            <div className="text-sm text-text-secondary mt-1">{a.expectedImpact}</div>
                                                        )}
                                                        {(a.targets?.length || a.relatedFindingIds?.length) ? (
                                                            <div className="text-xs text-text-tertiary mt-2 space-y-1">
                                                                {a.targets?.length ? <div>Targets: {a.targets.join(', ')}</div> : null}
                                                                {a.relatedFindingIds?.length ? <div>Related: {a.relatedFindingIds.join(', ')}</div> : null}
                                                            </div>
                                                        ) : null}
                                                    </div>
                                                ))}
                                            </div>
                                        ) : (
                                            <div className="text-sm text-text-tertiary">No immediate actions returned.</div>
                                        )}
                                    </div>
                                </>
                            ) : (
                                <div className="prose prose-invert max-w-none prose-sm prose-a:text-accent-orange prose-headings:text-text-primary prose-strong:text-text-primary text-text-secondary">
                                    <p>Select a data source and click \"Generate Attack Path\" to produce an executive summary, kill chains, choke points, immediate actions, and a Mermaid graph.</p>
                                </div>
                            )}
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
}

