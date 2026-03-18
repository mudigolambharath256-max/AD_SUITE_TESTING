import React, { useState } from 'react';
import { Brain, Network, FileText, Download, Upload, Search, AlertTriangle } from 'lucide-react';
import ReactFlow, {
  Background,
  Controls,
  MiniMap,
  useNodesState,
  useEdgesState,
  Handle
} from 'reactflow';
import 'reactflow/dist/style.css';
import { getRecentScans, analyzeWithLLM } from '../lib/api';
import { getSeverityColor } from '../lib/colours';

const AttackPath = () => {
  const [dataSource, setDataSource] = useState('recent');
  const [selectedScanId, setSelectedScanId] = useState('');
  const [severityFilter, setSeverityFilter] = useState(['critical', 'high']);
  const [llmProvider, setLlmProvider] = useState('anthropic');
  const [apiKey, setApiKey] = useState('');
  const [model, setModel] = useState('claude-3-sonnet-20240229');
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [narrative, setNarrative] = useState('');
  const [nodes, setNodes] = useState([]);
  const [edges, setEdges] = useState([]);
  const [recentScans, setRecentScans] = useState([]);
  const [findings, setFindings] = useState([]);
  const [error, setError] = useState(null);
  const [uploadedFile, setUploadedFile] = useState(null);
  const [bloodhoundDataAvailable, setBloodhoundDataAvailable] = useState(false);

  const [nodesState, setNodesState, onNodesChange] = useNodesState(nodes);
  const [edgesState, setEdgesState, onEdgesChange] = useEdgesState(edges);

  React.useEffect(() => {
    loadRecentScans();
  }, []);

  // Load findings when scan selection changes
  React.useEffect(() => {
    if (dataSource === 'recent' || dataSource === 'choose') {
      if (selectedScanId) {
        loadFindings(selectedScanId);
      }
    }
  }, [selectedScanId, dataSource, severityFilter]);

  React.useEffect(() => {
    setNodesState(nodes);
    setEdgesState(edges);
  }, [nodes, edges, setNodesState, setEdgesState]);

  // Update model when provider changes
  React.useEffect(() => {
    if (llmProvider === 'openai') {
      setModel('gpt-4o-mini');
    } else if (llmProvider === 'anthropic') {
      setModel('claude-3-sonnet-20240229');
    } else if (llmProvider === 'ollama') {
      setModel('llama3');
    }
  }, [llmProvider]);

  const loadRecentScans = async () => {
    try {
      const scans = await getRecentScans(10);
      setRecentScans(scans);
      if (scans.length > 0) {
        setSelectedScanId(scans[0].id);
        // Auto-load findings for the most recent scan if using recent data source
        if (dataSource === 'recent') {
          await loadFindings(scans[0].id);
        }
      }
    } catch (error) {
      console.error('Failed to load recent scans:', error);
      setError('Failed to load recent scans');
    }
  };

  const loadFindings = async (scanId) => {
    if (!scanId) return;

    try {
      setError(null);

      // First try to load BloodHound data from the scan
      const bloodhoundResponse = await fetch(`/api/bloodhound/scan/${scanId}`);

      if (bloodhoundResponse.ok) {
        const bloodhoundData = await bloodhoundResponse.json();

        if (bloodhoundData.nodes && bloodhoundData.nodes.length > 0) {
          console.log(`Loaded ${bloodhoundData.nodes.length} BloodHound nodes from scan ${scanId}`);
          setBloodhoundDataAvailable(true);

          // Convert BloodHound nodes to findings format for analysis
          const bhFindings = bloodhoundData.nodes.map(node => ({
            checkId: node.Properties?.adSuiteCheckId || 'UNKNOWN',
            category: node.Properties?.adSuiteCategory || 'Unknown',
            checkName: node.Properties?.adSuiteCheckName || 'Unknown Check',
            severity: node.Properties?.adSuiteSeverity?.toUpperCase() || 'INFO',
            riskScore: 0,
            mitre: '',
            name: node.Properties?.samaccountname || node.Properties?.name || 'Unknown',
            distinguishedName: node.Properties?.distinguishedname || '',
            detailsJson: JSON.stringify(node.Properties || {}),
            description: `BloodHound node: ${node.Properties?.name || 'Unknown'}`
          }));

          const filteredFindings = bhFindings.filter(finding =>
            severityFilter.includes(finding.severity.toLowerCase())
          );

          setFindings(filteredFindings);

          if (filteredFindings.length === 0 && bhFindings.length > 0) {
            setError(`No BloodHound findings match the selected severity filters. Total BloodHound nodes: ${bhFindings.length}`);
          }
          return;
        }
      }

      // Fallback to regular findings if no BloodHound data
      setBloodhoundDataAvailable(false);
      const response = await fetch(`/api/scan/${scanId}/findings`);

      if (!response.ok) {
        throw new Error(`Failed to load findings: ${response.status}`);
      }

      const data = await response.json();

      if (!data.findings || !Array.isArray(data.findings)) {
        throw new Error('Invalid findings data format');
      }

      const filteredFindings = data.findings.filter(finding =>
        severityFilter.includes(finding.severity.toLowerCase())
      );

      setFindings(filteredFindings);

      if (filteredFindings.length === 0 && data.findings.length > 0) {
        setError(`No findings match the selected severity filters. Total findings: ${data.findings.length}`);
      }
    } catch (error) {
      console.error('Failed to load findings:', error);
      setError(`Failed to load findings: ${error.message}`);
      setFindings([]);
    }
  };

  const handleAnalyze = async () => {
    if (!apiKey.trim()) {
      setError('API key is required');
      return;
    }

    if (findings.length === 0) {
      setError('No findings to analyze');
      return;
    }

    setIsAnalyzing(true);
    setError(null);

    try {
      const result = await analyzeWithLLM(findings, llmProvider, apiKey, model);
      setNarrative(result.narrative);

      // Convert LLM output to ReactFlow format
      const flowNodes = result.nodes.map((node, index) => ({
        id: node.id,
        type: 'customNode',
        position: {
          x: (index % 4) * 200,
          y: Math.floor(index / 4) * 150
        },
        data: {
          label: node.label,
          type: node.type,
          severity: node.severity
        }
      }));

      const flowEdges = result.edges.map(edge => ({
        id: `${edge.source}-${edge.target}`,
        source: edge.source,
        target: edge.target,
        label: edge.label,
        type: 'smoothstep'
      }));

      setNodes(flowNodes);
      setEdges(flowEdges);
    } catch (error) {
      console.error('Analysis failed:', error);
      setError(error.message);
    } finally {
      setIsAnalyzing(false);
    }
  };

  const loadGOADSample = () => {
    const goadData = [
      {
        "checkId": "AUTH-001",
        "category": "Authentication",
        "checkName": "Accounts Without Kerberos Pre-Auth",
        "severity": "HIGH",
        "riskScore": 8,
        "mitre": "T1558.003",
        "name": "sansa.stark",
        "distinguishedName": "CN=sansa.stark,OU=Stark,OU=Users,DC=sevenkingdoms,DC=local",
        "detailsJson": "{\"userAccountControl\": 4194304, \"description\": \"Stark family member\"}",
        "description": "Account sansa.stark does not require Kerberos pre-authentication, making it vulnerable to ASREPRoasting attacks"
      },
      {
        "checkId": "USR-002",
        "category": "Users_Accounts",
        "checkName": "Accounts Vulnerable to Kerberoasting",
        "severity": "HIGH",
        "riskScore": 8,
        "mitre": "T1558.004",
        "name": "tyrion.lannister",
        "distinguishedName": "CN=tyrion.lannister,OU=Lannister,OU=Users,DC=sevenkingdoms,DC=local",
        "detailsJson": "{\"servicePrincipalName\": \"HTTP/winterfell.sevenkingdoms.local\", \"userAccountControl\": 512}",
        "description": "Account tyrion.lannister has SPN and is vulnerable to Kerberoasting attacks"
      },
      {
        "checkId": "USR-019",
        "category": "Users_Accounts",
        "checkName": "Domain Admins Members",
        "severity": "CRITICAL",
        "riskScore": 10,
        "mitre": "T1069.002",
        "name": "eddard.stark",
        "distinguishedName": "CN=eddard.stark,OU=Domain Admins,DC=sevenkingdoms,DC=local",
        "detailsJson": "{\"memberOf\": [\"CN=Domain Admins,CN=Users,DC=sevenkingdoms,DC=local\", \"CN=Enterprise Admins,CN=Users,DC=sevenkingdoms,DC=local\"]}",
        "description": "eddard.stark is a member of Domain Admins and Enterprise Admins groups"
      },
      {
        "checkId": "ACC-001",
        "category": "Access_Control",
        "checkName": "Unconstrained Delegation Configuration",
        "severity": "HIGH",
        "riskScore": 8,
        "mitre": "T1208",
        "name": "winterfell-server",
        "distinguishedName": "CN=winterfell-server,OU=Servers,DC=sevenkingdoms,DC=local",
        "detailsJson": "{\"userAccountControl\": 528384, \"trustedForDelegation\": true}",
        "description": "winterfell-server has unconstrained delegation enabled"
      }
    ];

    setFindings(goadData);
    setUploadedFile({ name: 'goad-sample.json' });
    setError(null);
    console.log('Loaded GOAD sample data with', goadData.length, 'findings');
  };

  const loadAdvancedSample = () => {
    const advancedData = [
      {
        "checkId": "AUTH-001",
        "category": "Authentication",
        "checkName": "Accounts Without Kerberos Pre-Auth",
        "severity": "HIGH",
        "riskScore": 8,
        "mitre": "T1558.003",
        "name": "j.doe",
        "distinguishedName": "CN=j.doe,OU=Users,DC=contoso,DC=local",
        "detailsJson": "{\"userAccountControl\": 4194304, \"department\": \"Sales\"}",
        "description": "Account j.doe vulnerable to ASREPRoasting - no Kerberos pre-auth required"
      },
      {
        "checkId": "USR-002",
        "category": "Users_Accounts",
        "checkName": "Accounts Vulnerable to Kerberoasting",
        "severity": "HIGH",
        "riskScore": 8,
        "mitre": "T1558.004",
        "name": "sql.service",
        "distinguishedName": "CN=sql.service,OU=Service Accounts,DC=contoso,DC=local",
        "detailsJson": "{\"servicePrincipalName\": \"MSSQLSvc/sql01.contoso.local:1433\", \"userAccountControl\": 512}",
        "description": "Service account sql.service has SPN - vulnerable to Kerberoasting"
      },
      {
        "checkId": "USR-019",
        "category": "Users_Accounts",
        "checkName": "Domain Admins Members",
        "severity": "CRITICAL",
        "riskScore": 10,
        "mitre": "T1069.002",
        "name": "admin.admin",
        "distinguishedName": "CN=admin.admin,OU=Domain Admins,DC=contoso,DC=local",
        "detailsJson": "{\"memberOf\": [\"CN=Domain Admins,CN=Users,DC=contoso,DC=local\", \"CN=Enterprise Admins,CN=Users,DC=contoso,DC=local\", \"CN=Schema Admins,CN=Users,DC=contoso,DC=local\"]}",
        "description": "admin.admin is member of Domain Admins, Enterprise Admins, and Schema Admins"
      },
      {
        "checkId": "ACC-001",
        "category": "Access_Control",
        "checkName": "Unconstrained Delegation Configuration",
        "severity": "HIGH",
        "riskScore": 8,
        "mitre": "T1208",
        "name": "web01",
        "distinguishedName": "CN=web01,OU=Web Servers,DC=contoso,DC=local",
        "detailsJson": "{\"userAccountControl\": 528384, \"trustedForDelegation\": true, \"operatingSystem\": \"Windows Server 2016\"}",
        "description": "Web server web01 has unconstrained delegation - can be used for ticket theft"
      },
      {
        "checkId": "DC-001",
        "category": "Domain_Controllers",
        "checkName": "DC Sync Privileges",
        "severity": "CRITICAL",
        "riskScore": 10,
        "mitre": "T1003.006",
        "name": "backup.admin",
        "distinguishedName": "CN=backup.admin,OU=IT Admins,OU=Users,DC=contoso,DC=local",
        "detailsJson": "{\"extendedRights\": [\"1131f6aa-9c07-11d1-f79f-00c04fc2dcd2\"], \"memberOf\": [\"CN=Backup Operators,OU=Groups,DC=contoso,DC=local\"]}",
        "description": "backup.admin has DCSync rights - can extract all domain credentials"
      }
    ];

    setFindings(advancedData);
    setUploadedFile({ name: 'advanced-sample.json' });
    setError(null);
    console.log('Loaded advanced sample data with', advancedData.length, 'findings');
  };

  const handleFileUpload = async (event) => {
    const file = event.target.files[0];
    if (file) {
      setUploadedFile(file);
      setError(null);

      try {
        const text = await file.text();
        let data;

        if (file.name.endsWith('.json')) {
          const jsonContent = JSON.parse(text);
          // Handle both formats: direct findings array or wrapped in scanInfo
          data = jsonContent.findings || jsonContent;
        } else if (file.name.endsWith('.csv')) {
          // Parse CSV
          const lines = text.split('\n').filter(line => line.trim());
          const headers = lines[0].split(',').map(h => h.trim());

          data = lines.slice(1).map(line => {
            const values = line.split(',').map(v => v.trim().replace(/"/g, ''));
            const obj = {};
            headers.forEach((header, index) => {
              obj[header] = values[index];
            });
            return obj;
          });
        }

        if (Array.isArray(data) && data.length > 0) {
          setFindings(data);
          setError(null);
          console.log(`Loaded ${data.length} findings from ${file.name}`);
        } else {
          setError('No valid findings found in file');
        }
      } catch (error) {
        console.error('File parsing error:', error);
        setError(`Failed to parse file: ${error.message}`);
      }
    }
  };

  const toggleSeverity = (severity) => {
    setSeverityFilter(prev =>
      prev.includes(severity)
        ? prev.filter(s => s !== severity)
        : [...prev, severity]
    );
  };

  const nodeTypes = {
    customNode: ({ data }) => {
      const getNodeStyle = () => {
        switch (data.type) {
          case 'finding':
            return {
              background: getSeverityColor(data.severity).replace('bg-', '#'),
              color: 'white',
              border: `2px solid ${getSeverityColor(data.severity).replace('bg-', '#')}`,
              borderRadius: '8px',
              padding: '8px 12px',
              minWidth: '120px'
            };
          case 'object':
            return {
              background: '#5b7fa6',
              color: 'white',
              border: '2px solid #5b7fa6',
              borderRadius: '50%',
              width: '80px',
              height: '80px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            };
          case 'control':
            return {
              background: '#8b6db5',
              color: 'white',
              border: '2px solid #8b6db5',
              borderRadius: '4px',
              transform: 'rotate(45deg)',
              width: '60px',
              height: '60px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            };
          default:
            return {
              background: '#6b5f54',
              color: 'white',
              border: '2px solid #6b5f54',
              borderRadius: '4px',
              padding: '8px 12px'
            };
        }
      };

      const style = getNodeStyle();

      return (
        <div style={style}>
          {data.type === 'control' ? (
            <div style={{ transform: 'rotate(-45deg)', fontSize: '12px' }}>
              {data.label}
            </div>
          ) : (
            <div style={{ fontSize: '12px', textAlign: 'center' }}>
              {data.label}
            </div>
          )}
          <Handle type="target" position="top" />
          <Handle type="source" position="bottom" />
        </div>
      );
    }
  };

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-text-primary mb-2">Attack Path Analysis</h1>
        <p className="text-text-secondary">AI-powered attack chain identification and visualization</p>
      </div>

      {/* Configuration Row */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Data Source */}
        <div className="card">
          <h3 className="font-semibold text-text-primary mb-4">Data Source</h3>
          <div className="space-y-4">
            <div className="space-y-2">
              {[
                { value: 'recent', label: 'Most recent scan' },
                { value: 'choose', label: 'Choose scan' },
                { value: 'upload', label: 'Upload JSON/CSV' }
              ].map(option => (
                <label key={option.value} className="flex items-center gap-2">
                  <input
                    type="radio"
                    name="dataSource"
                    value={option.value}
                    checked={dataSource === option.value}
                    onChange={(e) => {
                      setDataSource(e.target.value);
                      // Clear findings when switching to upload mode
                      if (e.target.value === 'upload') {
                        setFindings([]);
                        setError(null);
                      }
                    }}
                    className="radio"
                  />
                  <span className="text-text-primary">{option.label}</span>
                </label>
              ))}
            </div>

            {dataSource === 'choose' && (
              <select
                value={selectedScanId}
                onChange={(e) => {
                  setSelectedScanId(e.target.value);
                  if (e.target.value) {
                    loadFindings(e.target.value);
                  }
                }}
                className="select"
              >
                <option value="">Select a scan...</option>
                {recentScans.map(scan => (
                  <option key={scan.id} value={scan.id}>
                    {new Date(scan.timestamp).toLocaleString()} - {scan.engine} ({scan.finding_count} findings)
                  </option>
                ))}
              </select>
            )}

            {dataSource === 'upload' && (
              <div className="space-y-4">
                <div className="upload-zone" onClick={() => document.getElementById('file-upload').click()}>
                  <Upload className="w-8 h-8 mx-auto mb-2 text-text-muted" />
                  <p className="text-sm text-text-secondary">
                    {uploadedFile ? uploadedFile.name : 'Click to upload or drag and drop'}
                  </p>
                  <p className="text-xs text-text-muted mt-1">JSON or CSV files</p>
                  <input
                    id="file-upload"
                    type="file"
                    accept=".json,.csv"
                    onChange={handleFileUpload}
                    className="hidden"
                  />
                </div>

                <div className="flex gap-2">
                  <button
                    onClick={loadGOADSample}
                    className="btn-secondary text-sm flex-1"
                  >
                    🎭 Load GOAD Sample
                  </button>
                  <button
                    onClick={loadAdvancedSample}
                    className="btn-secondary text-sm flex-1"
                  >
                    🏢 Load Advanced Sample
                  </button>
                </div>
              </div>
            )}

            {/* Severity Filter */}
            <div>
              <p className="text-sm text-text-secondary mb-2">Severity Filter:</p>
              <div className="flex flex-wrap gap-2">
                {['critical', 'high', 'medium', 'low', 'info'].map(severity => (
                  <button
                    key={severity}
                    onClick={() => toggleSeverity(severity)}
                    className={`severity-badge severity-${severity} ${severityFilter.includes(severity) ? 'ring-2 ring-accent-primary' : ''
                      }`}
                  >
                    {severity.toUpperCase()}
                  </button>
                ))}
              </div>
            </div>

            <div className="text-sm text-text-secondary">
              {findings.length} findings ready for analysis
              {bloodhoundDataAvailable && (
                <div className="flex items-center gap-1 mt-1 text-accent-primary">
                  <Network className="w-3 h-3" />
                  <span className="text-xs">BloodHound data available</span>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* LLM Settings */}
        <div className="card">
          <h3 className="font-semibold text-text-primary mb-4">LLM Settings</h3>
          <div className="space-y-4">
            <div>
              <label className="block text-sm text-text-secondary mb-2">Provider</label>
              <select
                value={llmProvider}
                onChange={(e) => setLlmProvider(e.target.value)}
                className="select"
              >
                <option value="anthropic">Anthropic Claude</option>
                <option value="openai">OpenAI</option>
                <option value="ollama">Ollama (local)</option>
              </select>
            </div>

            <div>
              <label className="block text-sm text-text-secondary mb-2">
                API Key <span className="text-xs text-text-muted">(Stored locally only)</span>
              </label>
              <input
                type="password"
                value={apiKey}
                onChange={(e) => setApiKey(e.target.value)}
                placeholder="Enter your API key"
                className="input"
              />
            </div>

            <div>
              <label className="block text-sm text-text-secondary mb-2">Model</label>
              <select
                value={model}
                onChange={(e) => setModel(e.target.value)}
                className="select"
              >
                {llmProvider === 'anthropic' && (
                  <>
                    <option value="claude-3-opus-20240229">Claude Opus</option>
                    <option value="claude-3-sonnet-20240229">Claude Sonnet</option>
                  </>
                )}
                {llmProvider === 'openai' && (
                  <>
                    <option value="gpt-4o-mini">GPT-4o Mini</option>
                    <option value="gpt-4o">GPT-4o</option>
                    <option value="gpt-4-turbo">GPT-4 Turbo</option>
                  </>
                )}
                {llmProvider === 'ollama' && (
                  <>
                    <option value="llama3">Llama 3</option>
                    <option value="mistral">Mistral</option>
                  </>
                )}
              </select>
            </div>

            <button
              onClick={handleAnalyze}
              disabled={isAnalyzing || !apiKey.trim()}
              className="btn-primary w-full"
            >
              {isAnalyzing ? (
                <>
                  <div className="animate-spin w-4 h-4 border-2 border-white border-t-transparent rounded-full mr-2"></div>
                  Analyzing {findings.length} findings...
                </>
              ) : (
                <>
                  <Brain className="w-4 h-4 mr-2" />
                  Analyse Attack Paths
                </>
              )}
            </button>
          </div>
        </div>
      </div>

      {/* Results */}
      {error && (
        <div className="card bg-severity-critical/10 border-severity-critical/30">
          <div className="flex items-center gap-2 text-severity-critical">
            <AlertTriangle className="w-5 h-5" />
            <span className="font-medium">Error</span>
          </div>
          <p className="text-text-secondary mt-2">{error}</p>
        </div>
      )}

      {narrative && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Attack Graph */}
          <div className="card">
            <div className="flex items-center justify-between mb-4">
              <h3 className="font-semibold text-text-primary">Attack Graph</h3>
              <button className="btn-secondary text-sm">
                <Download className="w-3 h-3 mr-1" />
                Export PNG
              </button>
            </div>
            <div style={{ height: '400px', border: '1px solid #3d3530', borderRadius: '8px' }}>
              <ReactFlow
                nodes={nodesState}
                edges={edgesState}
                onNodesChange={onNodesChange}
                onEdgesChange={onEdgesChange}
                nodeTypes={nodeTypes}
                fitView
              >
                <Background color="#1a1612" gap={16} />
                <Controls />
                <MiniMap
                  nodeColor={(node) => {
                    switch (node.data.type) {
                      case 'finding': return getSeverityColor(node.data.severity).replace('bg-', '#');
                      case 'object': return '#5b7fa6';
                      case 'control': return '#8b6db5';
                      default: return '#6b5f54';
                    }
                  }}
                />
              </ReactFlow>
            </div>
          </div>

          {/* Narrative */}
          <div className="card">
            <div className="flex items-center justify-between mb-4">
              <h3 className="font-semibold text-text-primary">Analysis Narrative</h3>
              <div className="flex gap-2">
                <button className="btn-secondary text-sm">
                  <FileText className="w-3 h-3 mr-1" />
                  Copy
                </button>
                <button className="btn-secondary text-sm">
                  <Download className="w-3 h-3 mr-1" />
                  Export PDF
                </button>
              </div>
            </div>
            <div className="prose prose-invert max-w-none">
              <div dangerouslySetInnerHTML={{ __html: narrative.replace(/\n/g, '<br>') }} />
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default AttackPath;
