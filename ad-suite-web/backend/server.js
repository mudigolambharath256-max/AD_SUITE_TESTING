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
    const { findings, provider, apiKey, model } = req.body;

    if (!findings || !Array.isArray(findings) || !provider || !apiKey) {
      return res.status(400).json({ error: 'Missing required parameters' });
    }

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
        return res.status(400).json({ error: 'Unsupported provider' });
    }

    res.json(response);
  } catch (error) {
    console.error('LLM analysis error:', error);
    res.status(500).json({ error: error.message });
  }
});

// LLM API helper functions
async function callAnthropicAPI(findings, apiKey, model = 'claude-3-sonnet-20240229') {
  const axios = require('axios');

  const systemPrompt = `You are an Active Directory penetration tester. Analyse the findings and identify attack chains. Format your response in Markdown. At the end, include a JSON block labelled \`\`\`graph containing nodes and edges arrays for visualisation: nodes have id, label, type (finding|object|control), severity. Edges have source, target, label.`;

  const userPrompt = JSON.stringify(findings, null, 2);

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
  const graphData = parseGraphFromResponse(narrative);

  return {
    narrative,
    nodes: graphData.nodes,
    edges: graphData.edges
  };
}

async function callOpenAIAPI(findings, apiKey, model = 'gpt-4') {
  const axios = require('axios');

  const systemPrompt = `You are an Active Directory penetration tester. Analyse the findings and identify attack chains. Format your response in Markdown. At the end, include a JSON block labelled \`\`\`graph containing nodes and edges arrays for visualisation: nodes have id, label, type (finding|object|control), severity. Edges have source, target, label.`;

  const userPrompt = JSON.stringify(findings, null, 2);

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
    const graphData = parseGraphFromResponse(narrative);

    return {
      narrative,
      nodes: graphData.nodes,
      edges: graphData.edges
    };
  } catch (error) {
    console.error('OpenAI API Error:', error.response?.data || error.message);
    throw new Error(`OpenAI API Error: ${error.response?.data?.error?.message || error.message}`);
  }
}

async function callOllamaAPI(findings, apiKey, model = 'llama3') {
  const axios = require('axios');

  const systemPrompt = `You are an Active Directory penetration tester. Analyse the findings and identify attack chains. Format your response in Markdown. At the end, include a JSON block labelled \`\`\`graph containing nodes and edges arrays for visualisation: nodes have id, label, type (finding|object|control), severity. Edges have source, target, label.`;

  const userPrompt = JSON.stringify(findings, null, 2);

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
  const graphData = parseGraphFromResponse(narrative);

  return {
    narrative,
    nodes: graphData.nodes,
    edges: graphData.edges
  };
}

function parseGraphFromResponse(narrative) {
  try {
    // Try to find graph data in different formats
    let graphMatch = narrative.match(/```graph\n([\s\S]*?)\n```/);
    if (!graphMatch) {
      graphMatch = narrative.match(/```json\n([\s\S]*?)\n```/);
    }

    if (graphMatch) {
      let graphText = graphMatch[1];
      const graphJson = JSON.parse(graphText);

      // Handle both formats: direct nodes/edges or wrapped in graph object
      if (graphJson.graph) {
        return {
          nodes: graphJson.graph.nodes || [],
          edges: graphJson.graph.edges || []
        };
      } else {
        return {
          nodes: graphJson.nodes || [],
          edges: graphJson.edges || []
        };
      }
    }
  } catch (error) {
    console.error('Error parsing graph from response:', error);
  }

  return { nodes: [], edges: [] };
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
