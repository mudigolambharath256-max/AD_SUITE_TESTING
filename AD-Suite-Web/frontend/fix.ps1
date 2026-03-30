$path = "c:\Users\acer\Music\AD_SUITE\AD-Suite-Web\frontend\src\pages\AttackPath.tsx"
$content = Get-Content -Raw -Path $path

$content = $content.Replace("import { Network, Settings, AlertCircle, FileText, Play, Loader2, CheckCircle2, Bot } from 'lucide-react';", "import { Network, Settings, AlertCircle, FileText, Play, Loader2, CheckCircle2, Bot, Upload } from 'lucide-react';")

$content = $content.Replace("    const [selectedScanId, setSelectedScanId] = useState<string>('');", 
"    const [selectedScanId, setSelectedScanId] = useState<string>('');
    const [localFindings, setLocalFindings] = useState<Finding[]>([]);
    const fileInputRef = useRef<HTMLInputElement>(null);")

$content = $content.Replace("    const payloadFindings = useMemo(() => {
        if (!activeFindings) return [];
        return activeFindings.filter(f => selectedSeverities.has(f.Severity || f.severity));
    }, [activeFindings, selectedSeverities]);",
"    const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        if (!file) return;

        const reader = new FileReader();
        reader.onload = (event) => {
            try {
                const doc = JSON.parse(event.target?.result as string);
                const results = doc.results ?? doc.Results ?? [];
                
                if (results.length === 0) {
                    alert('No findings found in the uploaded file.');
                }
                
                setLocalFindings(results);
                setSelectedScanId(''); // Clear server selection when local file is used
            } catch (err) {
                console.error('Failed to parse file', err);
                alert('Invalid JSON file uploaded.');
            }
        };
        reader.readAsText(file);
        
        if (fileInputRef.current) fileInputRef.current.value = '';
    };

    // Filter Findings prior to payload
    const payloadFindings = useMemo(() => {
        const sourceFindings = localFindings.length > 0 ? localFindings : (activeFindings || []);
        return sourceFindings.filter(f => selectedSeverities.has(f.Severity || f.severity));
    }, [activeFindings, localFindings, selectedSeverities]);")

$content = $content.Replace("                                <select 
                                    value={selectedScanId} onChange={e => setSelectedScanId(e.target.value)}
                                    className="w-full bg-bg-tertiary border border-border-medium rounded-lg px-3 py-2 text-sm text-text-primary outline-none focus:border-accent-orange"
                                >
                                    <option value="">Select a Scan...</option>", 
"                                <div className="flex gap-2">
                                <select 
                                    value={selectedScanId} onChange={e => {
                                        setSelectedScanId(e.target.value);
                                        setLocalFindings([]); // Clear local findings if server scan selected
                                    }}
                                    className="flex-1 bg-bg-tertiary border border-border-medium rounded-lg px-3 py-2 text-sm text-text-primary outline-none focus:border-accent-orange"
                                >
                                    <option value="">{localFindings.length > 0 ? 'Using Local File...' : 'Select a Scan...'}</option>")

$content = $content.Replace("                                    {scans?.map(s => (
                                        <option key={s.id} value={s.id}>{s.name} ({s.totalFindings} findings)</option>
                                    ))}
                                </select>", 
"                                    {scans?.map(s => (
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
                                </div>")

$content = $content.Replace("disabled={!selectedScanId || payloadFindings.length === 0 || analyzeMutation.isPending}", 
"disabled={!(selectedScanId || localFindings.length > 0) || payloadFindings.length === 0 || analyzeMutation.isPending}")

$content = $content.Replace("{selectedScanId && (
                            <p className="text-center text-xs text-text-tertiary mt-3">
                                {payloadFindings.length} findings queued for analysis.
                            </p>
                        )}",
"{(selectedScanId || localFindings.length > 0) && (
                            <p className="text-center text-xs text-text-tertiary mt-3">
                                {payloadFindings.length} findings queued for analysis.
                            </p>
                        )}")

$content | Set-Content -Path $path -Encoding UTF8
