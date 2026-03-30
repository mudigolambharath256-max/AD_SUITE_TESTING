const fs = require('fs');
const path = 'src/pages/AttackPath.tsx';
let code = fs.readFileSync(path, 'utf8').replace(/\r\n/g, '\n');

code = code.replace(
  "import { Network, Settings, AlertCircle, FileText, Play, Loader2, CheckCircle2, Bot } from 'lucide-react';",
  "import { Network, Settings, AlertCircle, FileText, Play, Loader2, CheckCircle2, Bot, Upload } from 'lucide-react';"
);

code = code.replace(
  "    const [selectedScanId, setSelectedScanId] = useState<string>('');\n    const [selectedSeverities, setSelectedSeverities] = useState<Set<string>>(new Set(['Critical', 'High']));",
  "    const [selectedScanId, setSelectedScanId] = useState<string>('');\n    const [localFindings, setLocalFindings] = useState<Finding[]>([]);\n    const [selectedSeverities, setSelectedSeverities] = useState<Set<string>>(new Set(['Critical', 'High']));\n    const fileInputRef = useRef<HTMLInputElement>(null);"
);

code = code.replace(
  "    const payloadFindings = useMemo(() => {\n        if (!activeFindings) return [];\n        return activeFindings.filter(f => selectedSeverities.has(f.Severity || f.severity));\n    }, [activeFindings, selectedSeverities]);",
  \    const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
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
                console.error("Failed to parse file", err);
                alert("Invalid JSON file uploaded.");
            }
        };
        reader.readAsText(file);
        
        if (fileInputRef.current) fileInputRef.current.value = '';
    };

    // Filter Findings prior to payload
    const payloadFindings = useMemo(() => {
        const sourceFindings = localFindings.length > 0 ? localFindings : (activeFindings || []);
        return sourceFindings.filter(f => selectedSeverities.has(f.Severity || f.severity));
    }, [activeFindings, localFindings, selectedSeverities]);\
);

code = code.replace(
  \                                <select \n                                    value={selectedScanId} onChange={e => setSelectedScanId(e.target.value)}\n                                    className="w-full bg-bg-tertiary border border-border-medium rounded-lg px-3 py-2 text-sm text-text-primary outline-none focus:border-accent-orange"\n                                >\n                                    <option value="">Select a Scan...</option>\,
  \                                <div className="flex gap-2">
                                <select 
                                    value={selectedScanId} onChange={e => {
                                        setSelectedScanId(e.target.value);
                                        setLocalFindings([]); // Clear local findings if server scan selected
                                    }}
                                    className="flex-1 bg-bg-tertiary border border-border-medium rounded-lg px-3 py-2 text-sm text-text-primary outline-none focus:border-accent-orange"
                                >
                                    <option value="">{localFindings.length > 0 ? 'Using Local File...' : 'Select a Scan...'}</option>\
);

code = code.replace(
  \                                    {scans?.map(s => (\n                                        <option key={s.id} value={s.id}>{s.name} ({s.totalFindings} findings)</option>\n                                    ))}\n                                </select>\,
  \                                    {scans?.map(s => (
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
                                </div>\
);

code = code.replace(
  "disabled={!selectedScanId || payloadFindings.length === 0 || analyzeMutation.isPending}",
  "disabled={!(selectedScanId || localFindings.length > 0) || payloadFindings.length === 0 || analyzeMutation.isPending}"
);

code = code.replace(/\{selectedScanId && \([\s\S]*?\{\w+\.length\} findings queued for analysis\.[\s\S]*?\<\/p\>\n                        \)\}/g,
  \{(selectedScanId || localFindings.length > 0) && (
                            <p className="text-center text-xs text-text-tertiary mt-3">
                                {payloadFindings.length} findings queued for analysis.
                            </p>
                        )}\
);

fs.writeFileSync(path, code);
console.log('Success file updated!');
