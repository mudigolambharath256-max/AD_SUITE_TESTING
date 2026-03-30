import { useState, useEffect, useRef, useMemo } from 'react';
import { useQuery, useMutation } from '@tanstack/react-query';
import ReactMarkdown from 'react-markdown';
import mermaid from 'mermaid';
import { Network, Settings, AlertCircle, FileText, Play, Loader2, CheckCircle2, Bot, Upload } from 'lucide-react';
import api from '../lib/api';

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
    narrative: string;
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
const MermaidGraph = ({ chart }: { chart: string }) => {
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
            className="w-full overflow-auto flex justify-center p-4 bg-bg-tertiary rounded-lg border border-border-medium"
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

    // Filter Findings prior to payload
    const payloadFindings = useMemo(() => {
        const sourceFindings = localFindings.length > 0 ? localFindings : (activeFindings || []);
        return sourceFindings.filter(f => selectedSeverities.has(f.Severity || f.severity));
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
            const res = await api.post('/attack-path/analyze', {
                findings: payloadFindings.map(f => ({
                    CheckId: f.CheckId,
                    CheckName: f.CheckName,
                    Severity: f.Severity || f.severity,
                    Category: f.Category,
                    Description: f.Description || f.Name,
                    Impact: f.RiskData || f.Impact || f.Message
                })),
                llmProvider: provider,
                model,
                apiKey: apiKey || undefined
            });
            return res.data as AnalysisResponse;
        }
    });

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
                                        setModel(e.target.value === 'ollama' ? 'llama3' : e.target.value === 'openai' ? 'gpt-4o' : 'claude-3-haiku-20240307');
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
                                {payloadFindings.length} findings queued for analysis.
                            </p>
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
                    <div className="bg-surface-elevated border border-border-light rounded-xl p-5 shadow-sm min-h-[300px]">
                        <h2 className="text-lg font-medium text-text-primary flex items-center gap-2 mb-4">
                            <Network size={20} className="text-accent-orange" /> Visual Graph
                        </h2>
                        
                        {!analyzeMutation.data ? (
                            <div className="h-48 flex flex-col items-center justify-center text-text-tertiary border-2 border-dashed border-border-medium rounded-lg">
                                <Bot size={32} className="mb-2" />
                                <p>Awaiting analysis execution.</p>
                            </div>
                        ) : analyzeMutation.data.mermaidChart ? (
                            <MermaidGraph chart={analyzeMutation.data.mermaidChart} />
                        ) : (
                            <div className="p-4 bg-bg-tertiary border border-border-medium rounded-lg text-text-secondary text-sm">
                                The AI did not return a valid Mermaid chart.
                            </div>
                        )}
                    </div>

                    {/* Narrative Panel */}
                    <div className="bg-surface-elevated border border-border-light rounded-xl p-5 shadow-sm flex-1">
                        <div className="flex items-center justify-between mb-4 pb-4 border-b border-border-light">
                            <h2 className="text-lg font-medium text-text-primary flex items-center gap-2">
                                <FileText size={20} className="text-text-secondary" /> Narrative Details
                            </h2>
                            {analyzeMutation.data && (
                                <div className="flex flex-wrap items-center gap-4 text-xs font-medium text-text-secondary">
                                    <span className="flex items-center gap-1"><CheckCircle2 size={14} className="text-green-500"/> {analyzeMutation.data.metadata.payloadRows ?? analyzeMutation.data.metadata.findingsCount} rows in prompt</span>
                                    <span className="bg-bg-tertiary px-2 py-1 rounded-md border border-border-medium">{analyzeMutation.data.metadata.provider.toUpperCase()}</span>
                                    <span className="bg-bg-tertiary px-2 py-1 rounded-md border border-border-medium">{analyzeMutation.data.metadata.duration} latency</span>
                                </div>
                            )}
                        </div>
                        
                        <div className="prose prose-invert max-w-none prose-sm prose-a:text-accent-orange prose-headings:text-text-primary prose-strong:text-text-primary text-text-secondary">
                            {analyzeMutation.error ? (
                                <div className="p-4 border border-critical/30 bg-critical/10 text-critical rounded-lg flex items-start gap-3">
                                    <AlertCircle className="mt-0.5 shrink-0" size={18} />
                                    <div>
                                        <strong>Analysis Failed:</strong>
                                        <p className="mt-1">{analyzeMutation.error.message}</p>
                                    </div>
                                </div>
                            ) : analyzeMutation.data ? (
                                <ReactMarkdown>
                                    {analyzeMutation.data.narrative}
                                </ReactMarkdown>
                            ) : (
                                <p>Select a data source and click "Generate Attack Path" to synthesize findings into a unified narrative threat report.</p>
                            )}
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
}

