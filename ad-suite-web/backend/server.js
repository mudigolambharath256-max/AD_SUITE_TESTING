const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const path = require('path');
const fs = require('fs');

// Import routes
const scanRoutes = require('./routes/scan');
const reportsRoutes = require('./routes/reports');
const integrationsRoutes = require('./routes/integrations');
const scheduleRoutes = require('./routes/schedule');
const settingsRoutes = require('./routes/settings');
const adexplorerRoutes = require('./routes/adexplorer');
const bloodhoundRoutes = require('./routes/bloodhound');

// Import services
const db = require('./services/db');

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(helmet({
  contentSecurityPolicy: false // Allow inline scripts for development
}));
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// API Routes
app.use('/api/scan', scanRoutes);
app.use('/api/reports', reportsRoutes);
app.use('/api/integrations', integrationsRoutes);
app.use('/api/integrations/adexplorer', adexplorerRoutes);
app.use('/api/schedules', scheduleRoutes);
app.use('/api/settings', settingsRoutes);
app.use('/api/bloodhound', bloodhoundRoutes);

// Health check endpoint
app.get('/api/health', (req, res) => {
  try {
    const suiteRoot = db.getSetting('suiteRoot');
    const dbSize = db.getDbSize();

    res.json({
      status: 'healthy',
      suiteRoot: suiteRoot || null,
      dbSize,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(500).json({
      status: 'error',
      error: error.message
    });
  }
});

// Categories endpoint
app.get('/api/categories', (req, res) => {
  try {
    // For now, return hardcoded categories
    // In production, this could be dynamically loaded from the suite
    const categories = [
      { id: "Access_Control", display: "Access Control", prefix: "ACC", checkCount: 45 },
      { id: "Advanced_Security", display: "Advanced Security", prefix: "ADV", checkCount: 10 },
      { id: "Authentication", display: "Authentication", prefix: "AUTH", checkCount: 33 },
      { id: "Azure_AD_Integration", display: "Azure AD Integration", prefix: "AAD", checkCount: 42 },
      { id: "Backup_Recovery", display: "Backup Recovery", prefix: "BCK", checkCount: 8 },
      { id: "Certificate_Services", display: "Certificate Services", prefix: "CERT", checkCount: 53 },
      { id: "Computer_Management", display: "Computer Management", prefix: "CMGMT", checkCount: 50 },
      { id: "Computers_Servers", display: "Computers & Servers", prefix: "CMP", checkCount: 60 },
      { id: "Domain_Configuration", display: "Domain Configuration", prefix: "DCONF", checkCount: 60 },
      { id: "Group_Policy", display: "Group Policy", prefix: "GPO", checkCount: 40 },
      { id: "Infrastructure", display: "Infrastructure", prefix: "INFRA", checkCount: 30 },
      { id: "Kerberos_Security", display: "Kerberos Security", prefix: "KRB", checkCount: 50 },
      { id: "LDAP_Security", display: "LDAP Security", prefix: "LDAP", checkCount: 25 },
      { id: "Miscellaneous", display: "Miscellaneous", prefix: "MISC", checkCount: 137 },
      { id: "Network_Security", display: "Network Security", prefix: "NET", checkCount: 30 },
      { id: "Privileged_Access", display: "Privileged Access", prefix: "PRV", checkCount: 50 },
      { id: "Service_Accounts", display: "Service Accounts", prefix: "SVC", checkCount: 40 },
      { id: "Users_Accounts", display: "Users & Accounts", prefix: "USR", checkCount: 70 },
    ];

    res.json(categories);
  } catch (error) {
    console.error('Error getting categories:', error);
    res.status(500).json({ error: error.message });
  }
});

// Dashboard endpoints
app.get('/api/dashboard/severity-summary', (req, res) => {
  try {
    const summary = db.getSeveritySummary();

    // Ensure all severity levels are present
    const defaultSummary = {
      CRITICAL: 0,
      HIGH: 0,
      MEDIUM: 0,
      LOW: 0,
      INFO: 0
    };

    const result = { ...defaultSummary };
    summary.forEach(item => {
      result[item.severity] = item.count;
    });

    res.json(result);
  } catch (error) {
    console.error('Error getting severity summary:', error);
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/dashboard/category-summary', (req, res) => {
  try {
    const summary = db.getCategorySummary();
    res.json(summary);
  } catch (error) {
    console.error('Error getting category summary:', error);
    res.status(500).json({ error: error.message });
  }
});

// GET /api/reports/graph-data/:scanId
// Converts scan findings into cytoscape node/edge format for the graph visualizer
app.get('/api/reports/graph-data/:scanId', (req, res) => {
  const findings = db.getScanFindings(req.params.scanId);
  if (!findings.length) return res.json({ nodes: [], edges: [], meta: { scanId: req.params.scanId } });

  const nodes = [];
  const edges = [];
  const seen = new Set();

  findings.forEach(f => {
    const id = f.distinguished_name || f.name || f.check_id + '_' + f.id;
    if (!seen.has(id)) {
      seen.add(id);
      nodes.push({
        id,
        label: f.name || f.check_id,
        type: mapCategoryToNodeType(f.category),
        properties: {
          severity: f.severity,
          checkId: f.check_id,
          checkName: f.check_name,
          category: f.category,
          mitre: f.mitre,
        }
      });
    }

    // Link finding to its category node
    const catId = 'cat_' + f.category;
    if (!seen.has(catId)) {
      seen.add(catId);
      nodes.push({ id: catId, label: f.category.replace(/_/g, ' '), type: 'Category', properties: {} });
    }
    edges.push({ source: id, target: catId, type: 'BelongsTo', label: 'BelongsTo' });
  });

  res.json({ nodes, edges, meta: { scanId: req.params.scanId, nodeCount: nodes.length, edgeCount: edges.length } });

  function mapCategoryToNodeType(cat) {
    if (cat?.includes('User') || cat?.includes('Account')) return 'User';
    if (cat?.includes('Group')) return 'Group';
    if (cat?.includes('Computer') || cat?.includes('Server')) return 'Computer';
    if (cat?.includes('Domain')) return 'Domain';
    if (cat?.includes('Kerberos') || cat?.includes('Trust')) return 'Finding';
    return 'Finding';
  }
});

// Settings endpoints
app.post('/api/settings', (req, res) => {
  try {
    const { key, value } = req.body;

    if (!key || value === undefined) {
      return res.status(400).json({ error: 'Key and value required' });
    }

    db.setSetting(key, value);
    res.json({ success: true });
  } catch (error) {
    console.error('Error setting value:', error);
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/settings/:key', (req, res) => {
  try {
    const { key } = req.params;
    const value = db.getSetting(key);

    if (value === null) {
      return res.status(404).json({ error: 'Setting not found' });
    }

    res.json({ value });
  } catch (error) {
    console.error('Error getting value:', error);
    res.status(500).json({ error: error.message });
  }
});

// LLM analysis endpoint
app.post('/api/llm/analyse', async (req, res) => {
  try {
    const { findings, provider, apiKey, model, chunkSize = 100 } = req.body;

    if (!findings || !Array.isArray(findings) || !provider || !apiKey) {
      return res.status(400).json({ error: 'Missing required parameters' });
    }

    // If findings exceed chunk size, process in chunks
    if (findings.length > chunkSize) {
      console.log(`Processing ${findings.length} findings in chunks of ${chunkSize}`);

      // Split findings into chunks
      const chunks = [];
      for (let i = 0; i < findings.length; i += chunkSize) {
        chunks.push(findings.slice(i, i + chunkSize));
      }

      // Process first chunk for now (can be extended to merge multiple chunks)
      const firstChunkResponse = await processLLMAnalysis(chunks[0], provider, apiKey, model);

      // Add metadata about chunking
      firstChunkResponse.metadata = {
        totalFindings: findings.length,
        analyzedFindings: chunks[0].length,
        chunked: true,
        totalChunks: chunks.length,
        currentChunk: 1
      };

      return res.json(firstChunkResponse);
    }

    // Process normally if within limits
    const response = await processLLMAnalysis(findings, provider, apiKey, model);
    response.metadata = {
      totalFindings: findings.length,
      analyzedFindings: findings.length,
      chunked: false
    };

    res.json(response);
  } catch (error) {
    console.error('LLM analysis error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Helper function to process LLM analysis
async function processLLMAnalysis(findings, provider, apiKey, model) {
  let response;

  switch (provider) {
    case 'anthropic':
      response = await callAnthropicAPI(findings, apiKey, model);
      break;
    case 'openai':
      response = await callOpenAIAPI(findings, apiKey, model);
      break;
    case 'ollama':
      response = await callOllamaAPI(findings, apiKey, model);
      break;
    default:
      throw new Error('Unsupported provider');
  }

  return response;
}

// LLM API helper functions
async function callAnthropicAPI(findings, apiKey, model = 'claude-3-sonnet-20240229') {
  const axios = require('axios');

  const systemPrompt = `You are an Active Directory penetration tester. Analyze the findings and identify attack chains.

CRITICAL RULES FOR NODE NAMING:
1. Use ACTUAL object names from the findings (usernames, computer names, group names)
2. DO NOT use generic labels like "Exploit SPN", "Priv User", "Check Ticket"
3. Extract the "name" field from each finding and use it in the graph
4. For attack techniques, combine with the actual object: "ASREPRoast sansa" not just "ASREPRoast"
5. Keep labels under 30 characters but prioritize actual names over generic terms

Format your response in two parts:

1. **Narrative Analysis** (Markdown format):
   - Provide a detailed analysis of the attack paths
   - Explain the vulnerabilities and their relationships
   - Describe potential attack scenarios
   - Include MITRE ATT&CK techniques

2. **Mermaid Diagram** (at the end):
   - Create a Mermaid flowchart showing the attack path with COLOR CODING
   - IMPORTANT: Use ACTUAL object names from findings (usernames, computers, groups)
   - Keep node labels SHORT and SIMPLE (max 30 characters)
   - Use ONLY alphanumeric characters, spaces, and hyphens in labels
   - NO special characters like parentheses, brackets, pipes, backslashes
   
   COLOR CODING RULES:
   - Use :::red for HIGH RISK nodes (Domain Admin, Enterprise Admin, final objectives)
   - Use :::orange for MEDIUM RISK nodes (privilege escalation steps, exploitation)
   - Use :::yellow for LOW RISK nodes (reconnaissance, initial access)
   - Use :::cyan for INFORMATION nodes (discovered assets, enumeration results)
   - Use :::green for STARTING POINT (attacker position)
   
   EXAMPLE with ACTUAL names from findings:
   \`\`\`mermaid
   graph LR
       A["Attacker"]:::green --> B["sansa.stark"]:::yellow
       B --> C["ASREPRoast"]:::orange
       C --> D["sql_svc"]:::yellow
       D --> E["Kerberoast"]:::orange
       E --> F["Domain Admins"]:::red
       
       classDef red fill:#ff6b6b,stroke:#c92a2a,stroke-width:2px,color:#fff
       classDef orange fill:#ff922b,stroke:#e8590c,stroke-width:2px,color:#fff
       classDef yellow fill:#ffd43b,stroke:#fab005,stroke-width:2px,color:#000
       classDef cyan fill:#22b8cf,stroke:#0c8599,stroke-width:2px,color:#fff
       classDef green fill:#51cf66,stroke:#2f9e44,stroke-width:2px,color:#fff
   \`\`\`
   
   - Use ACTUAL object names from the findings data
   - Show the attack flow from initial access to final objective
   - Use graph LR (left to right) or TD (top to bottom) based on complexity
   - Apply appropriate color classes to each node
   - GOOD: "Administrator", "vagrant", "sql_svc", "Domain Admins"
   - BAD: "Priv User", "Exploit SPN", "Check Ticket" (too generic)`;

  const userPrompt = `Analyze these Active Directory findings and create an attack path diagram:\n\n${JSON.stringify(findings, null, 2)}`;

  const response = await axios.post('https://api.anthropic.com/v1/messages', {
    model: model,
    max_tokens: 4000,
    system: systemPrompt,
    messages: [
      { role: 'user', content: userPrompt }
    ]
  }, {
    headers: {
      'x-api-key': apiKey,
      'Content-Type': 'application/json',
      'anthropic-version': '2023-06-01'
    }
  });

  const narrative = response.data.content[0].text;
  const mermaidChart = parseMermaidFromResponse(narrative);

  return {
    narrative,
    mermaidChart
  };
}

async function callOpenAIAPI(findings, apiKey, model = 'gpt-4') {
  const axios = require('axios');

  const systemPrompt = `You are an Active Directory penetration tester. Analyze the findings and identify attack chains.

CRITICAL RULES FOR NODE NAMING:
1. Use ACTUAL object names from the findings (usernames, computer names, group names)
2. DO NOT use generic labels like "Exploit SPN", "Priv User", "Check Ticket"
3. Extract the "name" field from each finding and use it in the graph
4. For attack techniques, combine with the actual object: "ASREPRoast sansa" not just "ASREPRoast"
5. Keep labels under 30 characters but prioritize actual names over generic terms

Format your response in two parts:

1. **Narrative Analysis** (Markdown format):
   - Provide a detailed analysis of the attack paths
   - Explain the vulnerabilities and their relationships
   - Describe potential attack scenarios
   - Include MITRE ATT&CK techniques

2. **Mermaid Diagram** (at the end):
   - Create a Mermaid flowchart showing the attack path with COLOR CODING
   - IMPORTANT: Use ACTUAL object names from findings (usernames, computers, groups)
   - Keep node labels SHORT and SIMPLE (max 30 characters)
   - Use ONLY alphanumeric characters, spaces, and hyphens in labels
   - NO special characters like parentheses, brackets, pipes, backslashes
   
   COLOR CODING RULES:
   - Use :::red for HIGH RISK nodes (Domain Admin, Enterprise Admin, final objectives)
   - Use :::orange for MEDIUM RISK nodes (privilege escalation steps, exploitation)
   - Use :::yellow for LOW RISK nodes (reconnaissance, initial access)
   - Use :::cyan for INFORMATION nodes (discovered assets, enumeration results)
   - Use :::green for STARTING POINT (attacker position)
   
   EXAMPLE with ACTUAL names from findings:
   \`\`\`mermaid
   graph LR
       A["Attacker"]:::green --> B["sansa.stark"]:::yellow
       B --> C["ASREPRoast"]:::orange
       C --> D["sql_svc"]:::yellow
       D --> E["Kerberoast"]:::orange
       E --> F["Domain Admins"]:::red
       
       classDef red fill:#ff6b6b,stroke:#c92a2a,stroke-width:2px,color:#fff
       classDef orange fill:#ff922b,stroke:#e8590c,stroke-width:2px,color:#fff
       classDef yellow fill:#ffd43b,stroke:#fab005,stroke-width:2px,color:#000
       classDef cyan fill:#22b8cf,stroke:#0c8599,stroke-width:2px,color:#fff
       classDef green fill:#51cf66,stroke:#2f9e44,stroke-width:2px,color:#fff
   \`\`\`
   
   - Use ACTUAL object names from the findings data
   - Show the attack flow from initial access to final objective
   - Use graph LR (left to right) or TD (top to bottom) based on complexity
   - Apply appropriate color classes to each node
   - GOOD: "Administrator", "vagrant", "sql_svc", "Domain Admins"
   - BAD: "Priv User", "Exploit SPN", "Check Ticket" (too generic)`;

  const userPrompt = `Analyze these Active Directory findings and create an attack path diagram:\n\n${JSON.stringify(findings, null, 2)}`;

  try {
    const response = await axios.post('https://api.openai.com/v1/chat/completions', {
      model: model,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt }
      ],
      max_tokens: 4000
    }, {
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      }
    });

    const narrative = response.data.choices[0].message.content;
    const mermaidChart = parseMermaidFromResponse(narrative);

    return {
      narrative,
      mermaidChart
    };
  } catch (error) {
    console.error('OpenAI API Error:', error.response?.data || error.message);
    throw new Error(`OpenAI API Error: ${error.response?.data?.error?.message || error.message}`);
  }
}

async function callOllamaAPI(findings, apiKey, model = 'llama3') {
  const axios = require('axios');

  const systemPrompt = `You are an Active Directory penetration tester. Analyze the findings and identify attack chains.

Format your response in two parts:

1. **Narrative Analysis** (Markdown format):
   - Provide a detailed analysis of the attack paths
   - Explain the vulnerabilities and their relationships
   - Describe potential attack scenarios
   - Include MITRE ATT&CK techniques

2. **Mermaid Diagram** (at the end):
   - Create a Mermaid flowchart showing the attack path with COLOR CODING
   - IMPORTANT: Keep node labels SHORT and SIMPLE (max 30 characters)
   - Use ONLY alphanumeric characters, spaces, and hyphens in labels
   - NO special characters like parentheses, brackets, pipes, backslashes
   
   COLOR CODING RULES:
   - Use :::red for HIGH RISK nodes (Domain Admin, Enterprise Admin, final objectives)
   - Use :::orange for MEDIUM RISK nodes (privilege escalation steps, exploitation)
   - Use :::yellow for LOW RISK nodes (reconnaissance, initial access)
   - Use :::cyan for INFORMATION nodes (discovered assets, enumeration results)
   - Use :::green for STARTING POINT (attacker position)
   
   Use this format:
   \`\`\`mermaid
   graph LR
       A["Attacker"]:::green --> B["Find vulnerable user"]:::cyan
       B --> C["ASREPRoast attack"]:::orange
       C --> D["Crack hash"]:::orange
       D --> E["User compromised"]:::red
       E --> F["Domain Admin"]:::red
       
       classDef red fill:#ff6b6b,stroke:#c92a2a,stroke-width:2px,color:#fff
       classDef orange fill:#ff922b,stroke:#e8590c,stroke-width:2px,color:#fff
       classDef yellow fill:#ffd43b,stroke:#fab005,stroke-width:2px,color:#000
       classDef cyan fill:#22b8cf,stroke:#0c8599,stroke-width:2px,color:#fff
       classDef green fill:#51cf66,stroke:#2f9e44,stroke-width:2px,color:#fff
   \`\`\`
   
   - Use descriptive but SHORT node labels
   - Show the attack flow from initial access to final objective
   - Use graph LR (left to right) or TD (top to bottom) based on complexity
   - Apply appropriate color classes to each node
   - Example good labels: "ASREPRoast User", "Kerberoast SPN", "Exploit Delegation"
   - Example bad labels: "sansa.stark (No Kerberos Pre-Auth Required)" - TOO LONG`;

  const userPrompt = `Analyze these Active Directory findings and create an attack path diagram:\n\n${JSON.stringify(findings, null, 2)}`;

  const response = await axios.post(`${apiKey}/api/generate`, {
    model: model,
    system: systemPrompt,
    prompt: userPrompt,
    stream: false
  }, {
    headers: {
      'Content-Type': 'application/json'
    }
  });

  const narrative = response.data.response;
  const mermaidChart = parseMermaidFromResponse(narrative);

  return {
    narrative,
    mermaidChart
  };
}

function parseMermaidFromResponse(narrative) {
  try {
    // Try to find mermaid diagram in the response
    let mermaidMatch = narrative.match(/```mermaid\n([\s\S]*?)\n```/);

    if (mermaidMatch) {
      let mermaidCode = mermaidMatch[1].trim();

      // Sanitize the mermaid code to fix common issues
      mermaidCode = sanitizeMermaidCode(mermaidCode);

      return mermaidCode;
    }

    // If no mermaid found, return a default diagram
    return `graph TD
    A["No Attack Path Diagram Generated"]
    A --> B["Please try again or check the narrative"]`;
  } catch (error) {
    console.error('Error parsing mermaid from response:', error);
    return `graph TD
    A["Error Parsing Diagram"]
    A --> B["Check console for details"]`;
  }
}

function sanitizeMermaidCode(code) {
  // Replace problematic characters in node labels
  // Mermaid doesn't like certain characters in labels without quotes

  // Split into lines
  let lines = code.split('\n');

  lines = lines.map(line => {
    // Match node definitions like: A[text] or A(text) or A{text}
    // Replace with quoted versions if they contain special chars
    line = line.replace(/(\w+)\[(.*?)\]/g, (match, nodeId, label) => {
      // Remove or escape problematic characters
      let cleanLabel = label
        .replace(/\(/g, '')
        .replace(/\)/g, '')
        .replace(/\[/g, '')
        .replace(/\]/g, '')
        .replace(/\{/g, '')
        .replace(/\}/g, '')
        .replace(/"/g, "'")
        .replace(/\|/g, '-')
        .replace(/\\/g, '/')
        .trim();

      // Limit label length
      if (cleanLabel.length > 50) {
        cleanLabel = cleanLabel.substring(0, 47) + '...';
      }

      return `${nodeId}["${cleanLabel}"]`;
    });

    // Handle parentheses nodes
    line = line.replace(/(\w+)\((.*?)\)/g, (match, nodeId, label) => {
      let cleanLabel = label
        .replace(/\(/g, '')
        .replace(/\)/g, '')
        .replace(/\[/g, '')
        .replace(/\]/g, '')
        .replace(/"/g, "'")
        .trim();

      if (cleanLabel.length > 50) {
        cleanLabel = cleanLabel.substring(0, 47) + '...';
      }

      return `${nodeId}("${cleanLabel}")`;
    });

    // Handle curly brace nodes
    line = line.replace(/(\w+)\{(.*?)\}/g, (match, nodeId, label) => {
      let cleanLabel = label
        .replace(/\{/g, '')
        .replace(/\}/g, '')
        .replace(/\[/g, '')
        .replace(/\]/g, '')
        .replace(/"/g, "'")
        .trim();

      if (cleanLabel.length > 50) {
        cleanLabel = cleanLabel.substring(0, 47) + '...';
      }

      return `${nodeId}{"${cleanLabel}"}`;
    });

    return line;
  });

  let result = lines.join('\n');

  // Add color class definitions if they don't exist
  if (!result.includes('classDef red') && !result.includes('classDef')) {
    result += `\n\nclassDef red fill:#ff6b6b,stroke:#c92a2a,stroke-width:2px,color:#fff
classDef orange fill:#ff922b,stroke:#e8590c,stroke-width:2px,color:#fff
classDef yellow fill:#ffd43b,stroke:#fab005,stroke-width:2px,color:#000
classDef cyan fill:#22b8cf,stroke:#0c8599,stroke-width:2px,color:#fff
classDef green fill:#51cf66,stroke:#2f9e44,stroke-width:2px,color:#fff`;
  }

  return result;
}

// Serve static files in production
if (process.env.NODE_ENV === 'production') {
  const frontendPath = path.join(__dirname, '..', 'frontend', 'dist');

  console.log('Frontend path:', frontendPath);
  console.log('Frontend exists:', fs.existsSync(frontendPath));

  if (fs.existsSync(frontendPath)) {
    app.use(express.static(frontendPath));

    // Handle SPA routing
    app.get('*', (req, res) => {
      res.sendFile(path.join(frontendPath, 'index.html'));
    });
  }
}

// Error handling middleware
app.use((error, req, res, next) => {
  console.error('Unhandled error:', error);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
const { attachTerminalServer } = require('./services/terminalServer');

const httpServer = app.listen(PORT, '0.0.0.0', () => {
  const os = require('os');
  const networkInterfaces = os.networkInterfaces();
  const addresses = [];

  // Get all IPv4 addresses
  Object.keys(networkInterfaces).forEach(interfaceName => {
    networkInterfaces[interfaceName].forEach(iface => {
      if (iface.family === 'IPv4' && !iface.internal) {
        addresses.push(iface.address);
      }
    });
  });

  console.log('[Server] Express running on:');
  console.log('  Local:   http://localhost:' + PORT);
  addresses.forEach(addr => {
    console.log('  Network: http://' + addr + ':' + PORT);
  });
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);

  if (process.env.NODE_ENV === 'production') {
    console.log('Serving frontend from:', path.join(__dirname, '../frontend/dist'));
  }

  attachTerminalServer(httpServer);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('Received SIGTERM, shutting down gracefully');
  db.close();
  httpServer.close();
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('Received SIGINT, shutting down gracefully');
  db.close();
  httpServer.close();
  process.exit(0);
});
