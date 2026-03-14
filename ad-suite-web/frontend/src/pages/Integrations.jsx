import React, { useState, useEffect } from 'react';
import {
  Database,
  Network,
  Server,
  CheckCircle,
  XCircle,
  AlertTriangle,
  Download,
  Upload,
  Play
} from 'lucide-react';
import {
  testBloodHoundConnection,
  pushToBloodHound,
  testNeo4jConnection,
  pushToNeo4j,
  testMCPConnection,
  pushToMCP,
  getRecentScans
} from '../lib/api';
import { AdExplorerSection } from '../components/AdExplorerSection';
import { AdGraphVisualiser } from '../components/AdGraphVisualiser';

const Integrations = () => {
  const [recentScans, setRecentScans] = useState([]);
  const [selectedScanId, setSelectedScanId] = useState('');
  const [loading, setLoading] = useState({});
  const [graphSessionId, setGraphSessionId] = useState('');

  // BloodHound state
  const [bloodhoundConfig, setBloodhoundConfig] = useState({
    url: 'http://localhost:8080',
    username: 'neo4j',
    password: '',
    version: 'CE'
  });
  const [bloodhoundStatus, setBloodhoundStatus] = useState(null);

  // Neo4j state
  const [neo4jConfig, setNeo4jConfig] = useState({
    boltUri: 'bolt://localhost:7687',
    username: 'neo4j',
    password: '',
    database: 'neo4j'
  });
  const [neo4jStatus, setNeo4jStatus] = useState(null);

  // MCP state
  const [mcpConfig, setMcpConfig] = useState({
    serverUrl: '',
    apiKey: '',
    workspaceId: ''
  });
  const [mcpStatus, setMcpStatus] = useState(null);

  useEffect(() => {
    loadRecentScans();
    loadSavedConfigs();
  }, []);

  const loadRecentScans = async () => {
    try {
      const scans = await getRecentScans(10);
      setRecentScans(scans);
      if (scans.length > 0) {
        setSelectedScanId(scans[0].id);
      }
    } catch (error) {
      console.error('Failed to load recent scans:', error);
    }
  };

  const loadSavedConfigs = () => {
    // Load saved configurations from localStorage
    const savedBH = localStorage.getItem('integration_bh_config');
    const savedNeo4j = localStorage.getItem('integration_neo4j_config');
    const savedMCP = localStorage.getItem('integration_mcp_config');

    if (savedBH) setBloodhoundConfig(JSON.parse(savedBH));
    if (savedNeo4j) setNeo4jConfig(JSON.parse(savedNeo4j));
    if (savedMCP) setMcpConfig(JSON.parse(savedMCP));
  };

  const saveConfig = (integration, config) => {
    localStorage.setItem(`integration_${integration}_config`, JSON.stringify(config));
  };

  const setLoadingState = (key, value) => {
    setLoading(prev => ({ ...prev, [key]: value }));
  };

  // BloodHound functions
  const testBloodHound = async () => {
    setLoadingState('bloodhound-test', true);
    try {
      const result = await testBloodHoundConnection(bloodhoundConfig);
      setBloodhoundStatus(result);
      saveConfig('bh', bloodhoundConfig);
    } catch (error) {
      setBloodhoundStatus({ connected: false, error: error.message });
    } finally {
      setLoadingState('bloodhound-test', false);
    }
  };

  const pushBloodHound = async () => {
    if (!selectedScanId) {
      alert('Please select a scan to push');
      return;
    }

    setLoadingState('bloodhound-push', true);
    try {
      const result = await pushToBloodHound(selectedScanId, bloodhoundConfig);
      if (result.pushed) {
        alert(`Successfully pushed ${result.count} findings to BloodHound`);
      } else {
        alert(`Push failed: ${result.error}`);
      }
    } catch (error) {
      alert(`Push failed: ${error.message}`);
    } finally {
      setLoadingState('bloodhound-push', false);
    }
  };

  // Neo4j functions
  const testNeo4j = async () => {
    setLoadingState('neo4j-test', true);
    try {
      const result = await testNeo4jConnection(neo4jConfig);
      setNeo4jStatus(result);
      saveConfig('neo4j', neo4jConfig);
    } catch (error) {
      setNeo4jStatus({ connected: false, error: error.message });
    } finally {
      setLoadingState('neo4j-test', false);
    }
  };

  const pushNeo4j = async () => {
    if (!selectedScanId) {
      alert('Please select a scan to push');
      return;
    }

    setLoadingState('neo4j-push', true);
    try {
      const result = await pushToNeo4j(selectedScanId, neo4jConfig);
      if (result.nodesCreated > 0) {
        alert(`Successfully pushed ${result.nodesCreated} nodes and ${result.relationshipsCreated} relationships to Neo4j`);
      } else {
        alert('Push failed or no data to push');
      }
    } catch (error) {
      alert(`Push failed: ${error.message}`);
    } finally {
      setLoadingState('neo4j-push', false);
    }
  };

  // MCP functions
  const testMCP = async () => {
    setLoadingState('mcp-test', true);
    try {
      const result = await testMCPConnection(mcpConfig);
      setMcpStatus(result);
      saveConfig('mcp', mcpConfig);
    } catch (error) {
      setMcpStatus({ connected: false, error: error.message });
    } finally {
      setLoadingState('mcp-test', false);
    }
  };

  const pushMCP = async () => {
    if (!selectedScanId) {
      alert('Please select a scan to push');
      return;
    }

    setLoadingState('mcp-push', true);
    try {
      const result = await pushToMCP(selectedScanId, mcpConfig);
      if (result.pushed) {
        alert(`Successfully pushed ${result.count} findings to MCP server`);
      } else {
        alert(`Push failed: ${result.error}`);
      }
    } catch (error) {
      alert(`Push failed: ${error.message}`);
    } finally {
      setLoadingState('mcp-push', false);
    }
  };

  const downloadBloodHoundJSON = () => {
    // In production, this would generate and download the JSON file
    alert('BloodHound JSON download not implemented in demo');
  };

  const getStatusIcon = (status) => {
    if (!status) return null;
    if (status.connected) {
      return <CheckCircle className="w-4 h-4 text-green-500" />;
    } else {
      return <XCircle className="w-4 h-4 text-red-500" />;
    }
  };

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-text-primary mb-2">Integrations</h1>
        <p className="text-text-secondary">Connect with external security tools and platforms</p>
      </div>

      {/* Status Overview */}
      <div className="flex gap-4">
        <div className="flex items-center gap-2 px-4 py-2 bg-bg-tertiary rounded-lg">
          {getStatusIcon(bloodhoundStatus)}
          <span className="text-sm">BloodHound</span>
        </div>
        <div className="flex items-center gap-2 px-4 py-2 bg-bg-tertiary rounded-lg">
          {getStatusIcon(neo4jStatus)}
          <span className="text-sm">Neo4j</span>
        </div>
        <div className="flex items-center gap-2 px-4 py-2 bg-bg-tertiary rounded-lg">
          {getStatusIcon(mcpStatus)}
          <span className="text-sm">MCP Server</span>
        </div>
      </div>

      {/* Scan Selection */}
      <div className="card">
        <h3 className="font-semibold text-text-primary mb-3">Select Scan</h3>
        <select
          value={selectedScanId}
          onChange={(e) => setSelectedScanId(e.target.value)}
          className="select"
        >
          {recentScans.map(scan => (
            <option key={scan.id} value={scan.id}>
              {new Date(scan.timestamp).toLocaleString()} - {scan.engine} ({scan.finding_count} findings)
            </option>
          ))}
        </select>
      </div>

      {/* Integration Cards */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* BloodHound Card */}
        <div className="card">
          <div className="flex items-center gap-3 mb-4">
            {getStatusIcon(bloodhoundStatus)}
            <h3 className="font-semibold text-text-primary">BloodHound</h3>
          </div>

          <div className="space-y-3">
            <div>
              <label className="block text-sm text-text-secondary mb-1">URL</label>
              <input
                type="text"
                value={bloodhoundConfig.url}
                onChange={(e) => setBloodhoundConfig(prev => ({ ...prev, url: e.target.value }))}
                className="input text-sm"
              />
            </div>

            <div>
              <label className="block text-sm text-text-secondary mb-1">Username</label>
              <input
                type="text"
                value={bloodhoundConfig.username}
                onChange={(e) => setBloodhoundConfig(prev => ({ ...prev, username: e.target.value }))}
                className="input text-sm"
              />
            </div>

            <div>
              <label className="block text-sm text-text-secondary mb-1">Password</label>
              <input
                type="password"
                value={bloodhoundConfig.password}
                onChange={(e) => setBloodhoundConfig(prev => ({ ...prev, password: e.target.value }))}
                className="input text-sm"
              />
            </div>

            <div>
              <label className="block text-sm text-text-secondary mb-1">Version</label>
              <select
                value={bloodhoundConfig.version}
                onChange={(e) => setBloodhoundConfig(prev => ({ ...prev, version: e.target.value }))}
                className="select text-sm"
              >
                <option value="CE">CE</option>
                <option value="Legacy">Legacy 4.x</option>
              </select>
            </div>

            {bloodhoundStatus?.error && (
              <div className="text-xs text-severity-critical">
                {bloodhoundStatus.error}
              </div>
            )}

            <div className="flex gap-2">
              <button
                onClick={testBloodHound}
                disabled={loading['bloodhound-test']}
                className="btn-secondary text-sm flex-1"
              >
                {loading['bloodhound-test'] ? 'Testing...' : 'Test Connection'}
              </button>
              <button
                onClick={pushBloodHound}
                disabled={loading['bloodhound-push'] || !bloodhoundStatus?.connected}
                className="btn-secondary text-sm flex-1"
              >
                {loading['bloodhound-push'] ? 'Pushing...' : 'Push Findings'}
              </button>
            </div>

            <button
              onClick={downloadBloodHoundJSON}
              className="btn-secondary text-sm w-full"
            >
              <Download className="w-3 h-3 mr-1" />
              Download BH JSON
            </button>
          </div>
        </div>

        {/* Neo4j Card */}
        <div className="card">
          <div className="flex items-center gap-3 mb-4">
            {getStatusIcon(neo4jStatus)}
            <h3 className="font-semibold text-text-primary">Neo4j Database</h3>
          </div>

          <div className="space-y-3">
            <div>
              <label className="block text-sm text-text-secondary mb-1">Bolt URI</label>
              <input
                type="text"
                value={neo4jConfig.boltUri}
                onChange={(e) => setNeo4jConfig(prev => ({ ...prev, boltUri: e.target.value }))}
                className="input text-sm"
              />
            </div>

            <div>
              <label className="block text-sm text-text-secondary mb-1">Username</label>
              <input
                type="text"
                value={neo4jConfig.username}
                onChange={(e) => setNeo4jConfig(prev => ({ ...prev, username: e.target.value }))}
                className="input text-sm"
              />
            </div>

            <div>
              <label className="block text-sm text-text-secondary mb-1">Password</label>
              <input
                type="password"
                value={neo4jConfig.password}
                onChange={(e) => setNeo4jConfig(prev => ({ ...prev, password: e.target.value }))}
                className="input text-sm"
              />
            </div>

            <div>
              <label className="block text-sm text-text-secondary mb-1">Database</label>
              <input
                type="text"
                value={neo4jConfig.database}
                onChange={(e) => setNeo4jConfig(prev => ({ ...prev, database: e.target.value }))}
                className="input text-sm"
              />
            </div>

            {neo4jStatus?.error && (
              <div className="text-xs text-severity-critical">
                {neo4jStatus.error}
              </div>
            )}

            <div className="flex gap-2">
              <button
                onClick={testNeo4j}
                disabled={loading['neo4j-test']}
                className="btn-secondary text-sm flex-1"
              >
                {loading['neo4j-test'] ? 'Testing...' : 'Test Connection'}
              </button>
              <button
                onClick={pushNeo4j}
                disabled={loading['neo4j-push'] || !neo4jStatus?.connected}
                className="btn-secondary text-sm flex-1"
              >
                {loading['neo4j-push'] ? 'Pushing...' : 'Push as Graph'}
              </button>
            </div>
          </div>
        </div>

        {/* MCP Server Card */}
        <div className="card">
          <div className="flex items-center gap-3 mb-4">
            {getStatusIcon(mcpStatus)}
            <h3 className="font-semibold text-text-primary">MCP Server</h3>
          </div>

          <div className="space-y-3">
            <div>
              <label className="block text-sm text-text-secondary mb-1">Server URL</label>
              <input
                type="text"
                value={mcpConfig.serverUrl}
                onChange={(e) => setMcpConfig(prev => ({ ...prev, serverUrl: e.target.value }))}
                placeholder="https://mcp.example.com"
                className="input text-sm"
              />
            </div>

            <div>
              <label className="block text-sm text-text-secondary mb-1">API Key</label>
              <input
                type="password"
                value={mcpConfig.apiKey}
                onChange={(e) => setMcpConfig(prev => ({ ...prev, apiKey: e.target.value }))}
                placeholder="Enter API key"
                className="input text-sm"
              />
            </div>

            <div>
              <label className="block text-sm text-text-secondary mb-1">Workspace ID</label>
              <input
                type="text"
                value={mcpConfig.workspaceId}
                onChange={(e) => setMcpConfig(prev => ({ ...prev, workspaceId: e.target.value }))}
                placeholder="Enter workspace ID"
                className="input text-sm"
              />
            </div>

            {mcpStatus?.error && (
              <div className="text-xs text-severity-critical">
                {mcpStatus.error}
              </div>
            )}

            <div className="flex gap-2">
              <button
                onClick={testMCP}
                disabled={loading['mcp-test']}
                className="btn-secondary text-sm flex-1"
              >
                {loading['mcp-test'] ? 'Testing...' : 'Test Connection'}
              </button>
              <button
                onClick={pushMCP}
                disabled={loading['mcp-push'] || !mcpStatus?.connected}
                className="btn-secondary text-sm flex-1"
              >
                {loading['mcp-push'] ? 'Pushing...' : 'Push Findings'}
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* ══ ADDITION A: ADExplorer Snapshot Converter ══ */}
      <AdExplorerSection onOpenInGraph={(sid) => setGraphSessionId(sid)} />

      {/* ══ ADDITION B: AD Graph Visualiser ══ */}
      <AdGraphVisualiser preloadSessionId={graphSessionId} />
    </div>
  );
};

export default Integrations;
