import React, { useState } from 'react';
import { Brain, Network, FileText, Download, Upload, Search, AlertTriangle } from 'lucide-react';
import MermaidGraph from '../components/MermaidGraph';
import { getRecentScans, analyzeWithLLM } from '../lib/api';
import LoadingSpinner from '../components/LoadingSpinner';
import SvgIcon from '../components/SvgIcon';

const AttackPath = () => {
  const [dataSource, setDataSource] = useState('recent');
  const [selectedScanId, setSelectedScanId] = useState('');
  const [severityFilter, setSeverityFilter] = useState(['critical', 'high']);
  const [llmProvider, setLlmProvider] = useState('anthropic');
  const [apiKey, setApiKey] = useState('');
  const [model, setModel] = useState('claude-3-sonnet-20240229');
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [narrative, setNarrative] = useState('');
  const [mermaidChart, setMermaidChart] = useState('');
  const [recentScans, setRecentScans] = useState([]);
  const [findings, setFindings] = useState([]);
  const [error, setError] = useState(null);
  const [uploadedFile, setUploadedFile] = useState(null);
  const [bloodhoundDataAvailable, setBloodhoundDataAvailable] = useState(false);
  const [maxFindings, setMaxFindings] = useState(100);
  const [analysisMetadata, setAnalysisMetadata] = useState(null);

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
    setAnalysisMetadata(null);

    try {
      // Automatic filtering: prioritize high-severity findings
      let filteredFindings = [...findings];

      // Sort by severity (CRITICAL > HIGH > MEDIUM > LOW > INFO)
      const severityOrder = { 'CRITICAL': 5, 'HIGH': 4, 'MEDIUM': 3, 'LOW': 2, 'INFO': 1 };
      filteredFindings.sort((a, b) => {
        const severityA = severityOrder[a.severity?.toUpperCase()] || 0;
        const severityB = severityOrder[b.severity?.toUpperCase()] || 0;
        return severityB - severityA;
      });

      // Limit to configured max findings
      let findingsToAnalyze = filteredFindings;

      if (filteredFindings.length > maxFindings) {
        findingsToAnalyze = filteredFindings.slice(0, maxFindings);
        console.log(`Filtered ${filteredFindings.length} findings down to top ${maxFindings} by severity`);
      }

      const result = await analyzeWithLLM(findingsToAnalyze, llmProvider, apiKey, model);
      setNarrative(result.narrative);
      setMermaidChart(result.mermaidChart || '');

      // Store metadata
      const metadata = result.metadata || {
        totalFindings: findings.length,
        analyzedFindings: findingsToAnalyze.length,
        chunked: false
      };
      setAnalysisMetadata(metadata);

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

  const openGraphInNewWindow = () => {
    if (!mermaidChart) return;

    // Create HTML content for the popup window
    const htmlContent = `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Attack Path Diagram - Interactive View</title>
  <script type="module">
    import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';
    mermaid.initialize({
      startOnLoad: true,
      theme: 'base',
      themeVariables: {
        darkMode: true,
        background: '#1a1612',
        primaryColor: '#4A90E2',
        primaryTextColor: '#fff',
        primaryBorderColor: '#4A90E2',
        lineColor: '#666',
        secondaryColor: '#E24A4A',
        tertiaryColor: '#50C878',
        fontSize: '16px',
        fontFamily: 'ui-sans-serif, system-ui, sans-serif',
        nodeBorder: '#666',
        mainBkg: '#2a2420',
        textColor: '#F5F1ED',
        edgeLabelBackground: '#1a1612',
        clusterBkg: '#2a2420',
        clusterBorder: '#666'
      },
      flowchart: {
        useMaxWidth: true,
        htmlLabels: true,
        curve: 'basis',
        padding: 20
      }
    });
  </script>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    body {
      background: #1a1612;
      color: #F5F1ED;
      font-family: ui-sans-serif, system-ui, sans-serif;
      overflow: hidden;
      display: flex;
      flex-direction: column;
      height: 100vh;
    }
    .header {
      background: #2a2420;
      padding: 15px 20px;
      border-bottom: 1px solid #3d3530;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .header h1 {
      font-size: 18px;
      font-weight: 600;
      color: #F5F1ED;
    }
    .controls {
      display: flex;
      gap: 10px;
    }
    .btn {
      background: #3d3530;
      color: #F5F1ED;
      border: 1px solid #4d4540;
      padding: 8px 16px;
      border-radius: 6px;
      cursor: pointer;
      font-size: 14px;
      transition: all 0.2s;
    }
    .btn:hover {
      background: #4d4540;
      border-color: #5d5550;
    }
    .container {
      flex: 1;
      display: flex;
      overflow: hidden;
    }
    .diagram-container {
      flex: 1;
      padding: 20px;
      overflow: auto;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .findings-panel {
      width: 400px;
      background: #2a2420;
      border-left: 1px solid #3d3530;
      padding: 20px;
      overflow-y: auto;
      display: none;
    }
    .findings-panel.active {
      display: block;
    }
    .finding-card {
      background: #1a1612;
      padding: 12px;
      border-radius: 6px;
      margin-bottom: 10px;
      border-left: 3px solid #4A90E2;
    }
    .severity-badge {
      display: inline-block;
      padding: 2px 8px;
      border-radius: 4px;
      font-size: 11px;
      font-weight: 600;
      color: white;
    }
    .severity-critical { background: #DC2626; }
    .severity-high { background: #EA580C; }
    .severity-medium { background: #F59E0B; }
    .severity-low { background: #10B981; }
    .severity-info { background: #3B82F6; }
    .mermaid {
      background: transparent;
    }
    .node {
      cursor: pointer;
      transition: opacity 0.2s;
    }
    .node:hover {
      opacity: 0.7;
      filter: brightness(1.2);
    }
    svg {
      max-width: 100%;
      max-height: 100%;
    }
    .close-findings {
      background: transparent;
      border: none;
      color: #999;
      font-size: 24px;
      cursor: pointer;
      float: right;
    }
    .node-title {
      background: #3d3530;
      padding: 12px;
      border-radius: 6px;
      margin-bottom: 15px;
      border-left: 3px solid #4A90E2;
    }
  </style>
</head>
<body>
  <div class="header">
    <h1>🎯 Attack Path Diagram - Interactive View</h1>
    <div class="controls">
      <button class="btn" onclick="zoomIn()">🔍 Zoom In</button>
      <button class="btn" onclick="zoomOut()">🔍 Zoom Out</button>
      <button class="btn" onclick="resetZoom()">↺ Reset</button>
      <button class="btn" onclick="exportPNG()">💾 Export PNG</button>
    </div>
  </div>
  <div class="container">
    <div class="diagram-container" id="diagram">
      <div class="mermaid">
${mermaidChart}
      </div>
    </div>
    <div class="findings-panel" id="findingsPanel">
      <button class="close-findings" onclick="closeFindings()">×</button>
      <div id="findingsContent"></div>
    </div>
  </div>
  <script>
    const findings = ${JSON.stringify(findings)};
    let currentZoom = 1;
    
    function zoomIn() {
      currentZoom += 0.2;
      applyZoom();
    }
    
    function zoomOut() {
      currentZoom = Math.max(0.2, currentZoom - 0.2);
      applyZoom();
    }
    
    function resetZoom() {
      currentZoom = 1;
      applyZoom();
    }
    
    function applyZoom() {
      const svg = document.querySelector('svg');
      if (svg) {
        svg.style.transform = 'scale(' + currentZoom + ')';
        svg.style.transformOrigin = 'center center';
      }
    }
    
    function exportPNG() {
      const svg = document.querySelector('svg');
      if (!svg) return;
      
      const svgData = new XMLSerializer().serializeToString(svg);
      const canvas = document.createElement('canvas');
      const ctx = canvas.getContext('2d');
      const img = new Image();
      
      canvas.width = svg.width.baseVal.value || 1200;
      canvas.height = svg.height.baseVal.value || 800;
      
      img.onload = function() {
        ctx.fillStyle = '#1a1612';
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        ctx.drawImage(img, 0, 0);
        
        const link = document.createElement('a');
        link.download = 'attack-path-diagram.png';
        link.href = canvas.toDataURL('image/png');
        link.click();
      };
      
      img.src = 'data:image/svg+xml;base64,' + btoa(unescape(encodeURIComponent(svgData)));
    }
    
    function findRelatedFindings(nodeLabel) {
      if (!nodeLabel || !findings || findings.length === 0) return [];
      
      const cleanLabel = nodeLabel.toLowerCase().replace(/['"]/g, '').trim();
      
      // Technique to category/check mapping for generic attack labels
      const techniqueMap = {
        'asreproast': ['AUTH-001', 'authentication', 'kerberos', 'pre-auth'],
        'kerberoast': ['USR-002', 'AUTH-002', 'spn', 'service principal'],
        'dcsync': ['DC-001', 'replication', 'domain controller'],
        'delegation': ['ACC-001', 'unconstrained', 'constrained', 'resource-based'],
        'golden ticket': ['AUTH-005', 'krbtgt'],
        'silver ticket': ['AUTH-006', 'service ticket'],
        'password spray': ['AUTH-003', 'password'],
        'domain admin': ['USR-019', 'domain admins', 'enterprise admins'],
        'privileged': ['ACC-001', 'ACC-002', 'admincount'],
        'exploit spn': ['USR-002', 'spn', 'kerberoast', 'service'],
        'priv user': ['ACC-001', 'privileged', 'admincount'],
        'check ticket': ['AUTH', 'kerberos', 'ticket'],
        'crack': ['password', 'hash', 'ntlm'],
        'access vigilant': ['ACC', 'access', 'control'],
        'escalate': ['privilege', 'escalation', 'elevation']
      };
      
      return findings.filter(finding => {
        const searchableText = \`
          \${finding.name || ''} 
          \${finding.checkName || ''} 
          \${finding.checkId || ''}
          \${finding.category || ''} 
          \${finding.description || ''}
          \${finding.distinguishedName || ''}
        \`.toLowerCase();
        
        // Strategy 1: Direct substring match
        if (searchableText.includes(cleanLabel)) return true;
        
        // Strategy 2: Check if finding name is in the node label
        const findingName = (finding.name || '').toLowerCase();
        if (findingName && cleanLabel.includes(findingName)) return true;
        
        // Strategy 3: Technique mapping - check if node label matches a known technique
        for (const [technique, keywords] of Object.entries(techniqueMap)) {
          if (cleanLabel.includes(technique)) {
            // Check if any keyword matches the finding
            if (keywords.some(keyword => searchableText.includes(keyword))) {
              return true;
            }
          }
        }
        
        // Strategy 4: Split node label and check each part (min 3 chars)
        const labelParts = cleanLabel.split(/\\s+/).filter(part => part.length >= 3);
        for (const part of labelParts) {
          if (searchableText.includes(part)) return true;
          
          // Also check with dots replaced by spaces
          const partWithSpaces = part.replace(/\\./g, ' ');
          if (partWithSpaces !== part && searchableText.includes(partWithSpaces)) return true;
        }
        
        // Strategy 5: Check for attack technique keywords
        const attackKeywords = ['asrep', 'kerberoast', 'delegation', 'dcsync', 'admin', 'privileged', 'unconstrained'];
        for (const keyword of attackKeywords) {
          if (cleanLabel.includes(keyword) && searchableText.includes(keyword)) return true;
        }
        
        return false;
      });
    }
    
    function showFindings(nodeLabel, relatedFindings) {
      const panel = document.getElementById('findingsPanel');
      const content = document.getElementById('findingsContent');
      
      let html = '<div class="node-title"><strong>' + nodeLabel + '</strong></div>';
      html += '<h3 style="margin-bottom: 10px; color: #C9BFB5;">Related Findings (' + relatedFindings.length + ')</h3>';
      
      if (relatedFindings.length === 0) {
        html += '<p style="color: #999; font-style: italic; text-align: center; padding: 20px;">No findings directly related to this node</p>';
      } else {
        relatedFindings.forEach(finding => {
          const severityClass = 'severity-' + (finding.severity || 'info').toLowerCase();
          html += '<div class="finding-card">';
          html += '<div style="display: flex; justify-content: space-between; margin-bottom: 8px;">';
          html += '<strong style="color: #F5F1ED; font-size: 13px;">' + (finding.checkName || finding.name) + '</strong>';
          html += '<span class="severity-badge ' + severityClass + '">' + (finding.severity || 'INFO') + '</span>';
          html += '</div>';
          if (finding.name) {
            html += '<div style="color: #C9BFB5; font-size: 12px; margin-bottom: 4px;"><strong>Object:</strong> ' + finding.name + '</div>';
          }
          if (finding.category) {
            html += '<div style="color: #999; font-size: 11px; margin-bottom: 4px;"><strong>Category:</strong> ' + finding.category.replace(/_/g, ' ') + '</div>';
          }
          if (finding.mitre) {
            html += '<div style="color: #999; font-size: 11px; margin-bottom: 4px;"><strong>MITRE:</strong> ' + finding.mitre + '</div>';
          }
          if (finding.description) {
            html += '<div style="color: #999; font-size: 11px; margin-top: 8px; line-height: 1.4;">' + finding.description + '</div>';
          }
          html += '</div>';
        });
      }
      
      content.innerHTML = html;
      panel.classList.add('active');
    }
    
    function closeFindings() {
      document.getElementById('findingsPanel').classList.remove('active');
    }
    
    // Add click handlers after mermaid renders
    setTimeout(() => {
      const nodes = document.querySelectorAll('.node');
      nodes.forEach(node => {
        node.addEventListener('click', (e) => {
          e.stopPropagation();
          const labelElement = node.querySelector('.nodeLabel, text');
          const nodeLabel = labelElement ? labelElement.textContent.trim() : '';
          const relatedFindings = findRelatedFindings(nodeLabel);
          showFindings(nodeLabel, relatedFindings);
        });
      });
    }, 1000);
  </script>
</body>
</html>
    `;

    // Open new window
    const newWindow = window.open('', '_blank', 'width=1400,height=900,menubar=no,toolbar=no,location=no,status=no');
    if (newWindow) {
      newWindow.document.write(htmlContent);
      newWindow.document.close();
    } else {
      alert('Please allow popups for this site to open the diagram in a new window');
    }
  };

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-text-primary mb-2">Attack Path Analysis</h1>
        <p className="text-text-secondary">AI-powered attack chain identification and visualization with Mermaid diagrams</p>
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

            <div>
              <label className="block text-sm text-text-secondary mb-2">
                Max Findings to Analyze
                <span className="text-xs text-text-muted ml-2">(Auto-filtered by severity)</span>
              </label>
              <select
                value={maxFindings}
                onChange={(e) => setMaxFindings(Number(e.target.value))}
                className="select"
              >
                <option value="50">50 findings</option>
                <option value="100">100 findings (Recommended)</option>
                <option value="200">200 findings</option>
                <option value="500">500 findings (May be slow)</option>
              </select>
              <p className="text-xs text-text-muted mt-1">
                Higher values may exceed LLM token limits or take longer to process
              </p>
            </div>

            <button
              onClick={handleAnalyze}
              disabled={isAnalyzing || !apiKey.trim()}
              className="btn-primary w-full"
            >
              {isAnalyzing ? (
                <div className="flex flex-col items-center">
                  <LoadingSpinner size="small" />
                  <span className="mt-2 text-sm">Analyzing {findings.length} findings...</span>
                </div>
              ) : (
                <>
                  <SvgIcon name="data-analysis" size={16} className="mr-2" />
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

      {/* Analysis Metadata */}
      {analysisMetadata && (
        <div className="card bg-accent-primary/10 border-accent-primary/30">
          <div className="flex items-center gap-2 text-accent-primary mb-2">
            <Brain className="w-5 h-5" />
            <span className="font-medium">Analysis Summary</span>
          </div>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
            <div>
              <div className="text-text-muted">Total Findings</div>
              <div className="text-text-primary font-semibold text-lg">{analysisMetadata.totalFindings}</div>
            </div>
            <div>
              <div className="text-text-muted">Analyzed</div>
              <div className="text-text-primary font-semibold text-lg">{analysisMetadata.analyzedFindings}</div>
            </div>
            <div>
              <div className="text-text-muted">Filtering</div>
              <div className="text-text-primary font-semibold text-lg">
                {analysisMetadata.analyzedFindings < analysisMetadata.totalFindings ? 'Top Severity' : 'All'}
              </div>
            </div>
            <div>
              <div className="text-text-muted">Processing</div>
              <div className="text-text-primary font-semibold text-lg">
                {analysisMetadata.chunked ? `Chunked (${analysisMetadata.currentChunk}/${analysisMetadata.totalChunks})` : 'Single Pass'}
              </div>
            </div>
          </div>
          {analysisMetadata.analyzedFindings < analysisMetadata.totalFindings && (
            <p className="text-xs text-text-muted mt-3">
              ℹ️ Automatically filtered to top {analysisMetadata.analyzedFindings} highest-severity findings for optimal LLM performance
            </p>
          )}
        </div>
      )}

      {narrative && (
        <div className="space-y-6">
          {/* Attack Graph - Full Width */}
          <div className="card">
            <div className="flex items-center justify-between mb-4">
              <h3 className="font-semibold text-text-primary text-lg">Attack Path Diagram</h3>
              <div className="flex gap-2">
                <button
                  onClick={() => openGraphInNewWindow()}
                  className="btn-secondary text-sm"
                  disabled={!mermaidChart}
                >
                  <Network className="w-3 h-3 mr-1" />
                  Open in New Window
                </button>
                <button className="btn-secondary text-sm">
                  <Download className="w-3 h-3 mr-1" />
                  Export PNG
                </button>
              </div>
            </div>
            <div style={{ height: '800px', width: '100%' }}>
              {mermaidChart ? (
                <MermaidGraph
                  chart={mermaidChart}
                  findings={findings}
                />
              ) : (
                <div className="flex items-center justify-center h-full text-text-secondary">
                  <div className="text-center">
                    <Network className="w-12 h-12 mx-auto mb-2 opacity-50" />
                    <p>No diagram generated yet</p>
                    <p className="text-sm text-text-muted mt-1">Run analysis to generate attack path</p>
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* Narrative - Full Width Below */}
          <div className="card">
            <div className="flex items-center justify-between mb-4">
              <h3 className="font-semibold text-text-primary text-lg">Analysis Narrative</h3>
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

          {/* Findings Data Table */}
          <div className="card">
            <div className="flex items-center justify-between mb-4">
              <h3 className="font-semibold text-text-primary text-lg">
                Compromised/Vulnerable Objects ({findings.length})
              </h3>
              <div className="flex gap-2">
                <button
                  onClick={() => {
                    const csv = [
                      ['Name', 'Check', 'Category', 'Severity', 'MITRE', 'Distinguished Name', 'Description'].join(','),
                      ...findings.map(f => [
                        f.name || '',
                        f.checkName || '',
                        f.category || '',
                        f.severity || '',
                        f.mitre || '',
                        f.distinguishedName || '',
                        (f.description || '').replace(/,/g, ';')
                      ].join(','))
                    ].join('\n');
                    const blob = new Blob([csv], { type: 'text/csv' });
                    const url = window.URL.createObjectURL(blob);
                    const a = document.createElement('a');
                    a.href = url;
                    a.download = 'findings-data.csv';
                    a.click();
                  }}
                  className="btn-secondary text-sm"
                >
                  <Download className="w-3 h-3 mr-1" />
                  Export CSV
                </button>
                <button
                  onClick={() => {
                    const json = JSON.stringify(findings, null, 2);
                    const blob = new Blob([json], { type: 'application/json' });
                    const url = window.URL.createObjectURL(blob);
                    const a = document.createElement('a');
                    a.href = url;
                    a.download = 'findings-data.json';
                    a.click();
                  }}
                  className="btn-secondary text-sm"
                >
                  <Download className="w-3 h-3 mr-1" />
                  Export JSON
                </button>
              </div>
            </div>

            <div className="overflow-x-auto">
              <table className="table">
                <thead>
                  <tr>
                    <th>Object Name</th>
                    <th>Check</th>
                    <th>Category</th>
                    <th>Severity</th>
                    <th>MITRE</th>
                    <th>Description</th>
                  </tr>
                </thead>
                <tbody>
                  {findings.length === 0 ? (
                    <tr>
                      <td colSpan="6" className="text-center py-8 text-text-muted">
                        No findings data available
                      </td>
                    </tr>
                  ) : (
                    findings.map((finding, index) => (
                      <tr key={index}>
                        <td>
                          <div className="font-mono text-sm text-accent-primary">
                            {finding.name || 'N/A'}
                          </div>
                          {finding.distinguishedName && (
                            <div className="text-xs text-text-muted mt-1 truncate max-w-xs" title={finding.distinguishedName}>
                              {finding.distinguishedName}
                            </div>
                          )}
                        </td>
                        <td>
                          <div className="text-sm">{finding.checkName || finding.checkId || 'N/A'}</div>
                          {finding.checkId && finding.checkName && (
                            <div className="text-xs text-text-muted">{finding.checkId}</div>
                          )}
                        </td>
                        <td>
                          <span className="text-sm">
                            {(finding.category || 'Unknown').replace(/_/g, ' ')}
                          </span>
                        </td>
                        <td>
                          <span className={`severity-badge severity-${(finding.severity || 'info').toLowerCase()}`}>
                            {(finding.severity || 'INFO').toUpperCase()}
                          </span>
                        </td>
                        <td>
                          {finding.mitre ? (
                            <a
                              href={`https://attack.mitre.org/techniques/${finding.mitre}/`}
                              target="_blank"
                              rel="noopener noreferrer"
                              className="text-accent-primary hover:underline text-sm font-mono"
                            >
                              {finding.mitre}
                            </a>
                          ) : (
                            <span className="text-text-muted text-sm">-</span>
                          )}
                        </td>
                        <td>
                          <div className="text-sm text-text-secondary max-w-md">
                            {finding.description || 'No description available'}
                          </div>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default AttackPath;
