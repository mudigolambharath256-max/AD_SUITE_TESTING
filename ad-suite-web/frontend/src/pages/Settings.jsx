import React, { useState, useEffect } from 'react';
import {
  FolderOpen,
  Terminal,
  Database,
  Palette,
  Info,
  CheckCircle,
  AlertTriangle,
  RefreshCw,
  Folder
} from 'lucide-react';
import { getSetting, setSetting, getHealth, browseFolderNative } from '../lib/api';
import FolderBrowser from '../components/FolderBrowser';
import SvgIcon from '../components/SvgIcon';

const Settings = () => {
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState(null);
  const [health, setHealth] = useState(null);

  // Technieum AD Suite Configuration
  const [suiteRoot, setSuiteRoot] = useState('');
  const [validation, setValidation] = useState(null);
  const [showFolderBrowser, setShowFolderBrowser] = useState(false);

  // PowerShell Settings
  const [executionPolicy, setExecutionPolicy] = useState('Bypass');
  const [extraFlags, setExtraFlags] = useState({
    NonInteractive: true,
    NoProfile: true,
    WindowStyleHidden: false
  });
  const [psTestResult, setPsTestResult] = useState(null);

  // C# Compiler Settings
  const [cscPath, setCscPath] = useState('');
  const [dotnetPath, setDotnetPath] = useState('');

  // Database Settings
  const [dbSize, setDbSize] = useState(0);
  const [clearHistoryDays, setClearHistoryDays] = useState(30);

  // Appearance Settings
  const [tableDensity, setTableDensity] = useState('comfortable');
  const [terminalFontSize, setTerminalFontSize] = useState(12);

  useEffect(() => {
    loadSettings();
    loadHealth();
  }, []);

  const loadSettings = async () => {
    try {
      const settings = await Promise.all([
        getSetting('suiteRoot').catch(() => ({ value: '' })),
        getSetting('executionPolicy').catch(() => ({ value: 'Bypass' })),
        getSetting('extraFlags').catch(() => ({ value: JSON.stringify({ NonInteractive: true, NoProfile: true, WindowStyleHidden: false }) })),
        getSetting('cscPath').catch(() => ({ value: '' })),
        getSetting('dotnetPath').catch(() => ({ value: '' })),
        getSetting('tableDensity').catch(() => ({ value: 'comfortable' })),
        getSetting('terminalFontSize').catch(() => ({ value: '12' }))
      ]);

      setSuiteRoot(settings[0].value);
      setExecutionPolicy(settings[1].value);
      setExtraFlags(JSON.parse(settings[2].value || '{}'));
      setCscPath(settings[3].value);
      setDotnetPath(settings[4].value);
      setTableDensity(settings[5].value);
      setTerminalFontSize(parseInt(settings[6].value) || 12);
    } catch (error) {
      console.error('Failed to load settings:', error);
    }
  };

  const loadHealth = async () => {
    try {
      const healthData = await getHealth();
      setHealth(healthData);
      setDbSize(healthData.dbSize || 0);
    } catch (error) {
      console.error('Failed to load health:', error);
    }
  };

  const saveSetting = async (key, value) => {
    try {
      setLoading(true);
      await setSetting(key, value);
      showMessage('Setting saved successfully', 'success');
    } catch (error) {
      console.error('Failed to save setting:', error);
      showMessage('Failed to save setting', 'error');
    } finally {
      setLoading(false);
    }
  };

  const showMessage = (text, type) => {
    setMessage({ text, type });
    setTimeout(() => setMessage(null), 3000);
  };

  const handleFolderSelect = (selectedPath) => {
    setSuiteRoot(selectedPath);
    setShowFolderBrowser(false);
  };

  const handleBrowseClick = async () => {
    try {
      setLoading(true);
      const result = await browseFolderNative();

      if (result.success && result.path) {
        setSuiteRoot(result.path);
      } else if (!result.cancelled) {
        showMessage('Failed to open folder browser', 'error');
      }
    } catch (error) {
      console.error('Error opening folder browser:', error);
      showMessage('Failed to open folder browser', 'error');
    } finally {
      setLoading(false);
    }
  };

  const testPowerShell = async () => {
    try {
      setLoading(true);
      setPsTestResult(null);
      const response = await fetch('/api/settings/test-execution-policy', { method: 'POST' });
      const result = await response.json();

      if (result.ok) {
        setPsTestResult({ ok: true, message: 'PowerShell is working correctly' });
        showMessage('PowerShell test passed', 'success');
      } else {
        setPsTestResult({ ok: false, message: result.error });
        showMessage('PowerShell test failed', 'error');
      }
    } catch (error) {
      setPsTestResult({ ok: false, message: error.message });
      showMessage('PowerShell test failed', 'error');
    } finally {
      setLoading(false);
    }
  };

  const validateSuiteRoot = async () => {
    if (!suiteRoot.trim()) {
      setValidation({ valid: false, error: 'Suite root path is required' });
      return;
    }

    try {
      setLoading(true);
      const response = await fetch(`/api/settings/suite-info?path=${encodeURIComponent(suiteRoot)}`);
      const result = await response.json();

      if (result.valid) {
        setValidation({
          valid: true,
          message: `Found ${result.checks} checks across ${result.categories} categories`
        });
        await saveSetting('suiteRoot', suiteRoot);
      } else {
        setValidation({ valid: false, error: result.error || 'Invalid suite root path' });
      }
    } catch (error) {
      setValidation({ valid: false, error: error.message });
    } finally {
      setLoading(false);
    }
  };

  const detectCscPath = async () => {
    try {
      setLoading(true);
      const response = await fetch('/api/settings/detect-csc', { method: 'POST' });
      const result = await response.json();

      if (result.found) {
        setCscPath(result.path);
        await saveSetting('cscPath', result.path);
        showMessage('C# compiler detected successfully', 'success');
      } else {
        showMessage('C# compiler not found. Please set path manually.', 'error');
      }
    } catch (error) {
      showMessage('Failed to detect C# compiler', 'error');
    } finally {
      setLoading(false);
    }
  };

  const exportDatabase = async () => {
    try {
      setLoading(true);
      const response = await fetch('/api/settings/export-db', { method: 'POST' });

      if (!response.ok) {
        throw new Error('Export failed');
      }

      const blob = await response.blob();
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `ad-suite-${Date.now()}.db`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      window.URL.revokeObjectURL(url);

      showMessage('Database exported successfully', 'success');
    } catch (error) {
      showMessage('Failed to export database', 'error');
    } finally {
      setLoading(false);
    }
  };

  const clearHistory = async () => {
    if (!confirm(`Are you sure you want to clear all scan history?`)) {
      return;
    }

    try {
      setLoading(true);
      const response = await fetch('/api/settings/clear-history', { method: 'POST' });
      const result = await response.json();

      if (result.success) {
        showMessage('Scan history cleared successfully', 'success');
        await loadHealth(); // Refresh DB size
      } else {
        showMessage('Failed to clear history', 'error');
      }
    } catch (error) {
      showMessage('Failed to clear history', 'error');
    } finally {
      setLoading(false);
    }
  };

  const resetAllData = async () => {
    if (!confirm('Are you sure you want to reset all data? This action cannot be undone and will delete all scan history, findings, and settings.')) {
      return;
    }

    if (!confirm('FINAL WARNING: This will permanently delete ALL data. Type YES in the next prompt to confirm.')) {
      return;
    }

    try {
      setLoading(true);
      const response = await fetch('/api/settings/reset-db', { method: 'POST' });
      const result = await response.json();

      if (result.success) {
        showMessage('Database reset successfully', 'success');
        await loadHealth(); // Refresh DB size
        await loadSettings(); // Reload settings
      } else {
        showMessage('Failed to reset database', 'error');
      }
    } catch (error) {
      showMessage('Failed to reset database', 'error');
    } finally {
      setLoading(false);
    }
  };

  const formatBytes = (bytes) => {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  };

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-text-primary mb-2">Settings</h1>
        <p className="text-text-secondary">Configure AD Security Suite preferences and options</p>
      </div>

      {/* Message Display */}
      {message && (
        <div className={`card ${message.type === 'success' ? 'bg-severity-low/10 border-severity-low/30 text-severity-low' :
          message.type === 'error' ? 'bg-severity-critical/10 border-severity-critical/30 text-severity-critical' :
            'bg-severity-info/10 border-severity-info/30 text-severity-info'
          }`}>
          <div className="flex items-center gap-2">
            {message.type === 'success' && <CheckCircle className="w-4 h-4" />}
            {message.type === 'error' && <AlertTriangle className="w-4 h-4" />}
            {message.type === 'info' && <Info className="w-4 h-4" />}
            <span>{message.text}</span>
          </div>
        </div>
      )}

      {/* Technieum AD Suite Configuration */}
      <div className="card">
        <div className="flex items-center gap-2 mb-4">
          <FolderOpen className="w-5 h-5 text-accent-primary" />
          <h3 className="font-semibold text-text-primary">Technieum AD Suite Configuration</h3>
        </div>

        <div className="space-y-4">
          <div>
            <label className="block text-sm text-text-secondary mb-2">Suite Root Path</label>
            <div className="flex gap-2">
              <input
                type="text"
                value={suiteRoot}
                onChange={(e) => setSuiteRoot(e.target.value)}
                placeholder="C:\ADSuite\AD-Suite-scripts-main"
                className={`input flex-1 ${validation?.valid ? 'input-success' : validation?.valid === false ? 'input-error' : ''}`}
              />
              <button
                onClick={handleBrowseClick}
                disabled={loading}
                className="btn-secondary"
                title="Browse for folder"
              >
                <Folder className="w-4 h-4" />
              </button>
              <button onClick={validateSuiteRoot} disabled={loading} className="btn-secondary">
                Validate
              </button>
            </div>
            {validation && (
              <div className={`flex items-center gap-1 text-sm mt-2 ${validation.valid ? 'text-severity-low' : 'text-severity-critical'
                }`}>
                {validation.valid ? (
                  <CheckCircle className="w-4 h-4" />
                ) : (
                  <AlertTriangle className="w-4 h-4" />
                )}
                <span>{validation.message || validation.error}</span>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* PowerShell Settings */}
      <div className="card">
        <div className="flex items-center gap-2 mb-4">
          <Terminal className="w-5 h-5 text-accent-primary" />
          <h3 className="font-semibold text-text-primary">PowerShell</h3>
        </div>

        <div className="space-y-4">
          <div>
            <label className="block text-sm text-text-secondary mb-2">Execution Policy</label>
            <div className="flex gap-2">
              {['Bypass', 'RemoteSigned', 'Unrestricted'].map(policy => (
                <label key={policy} className="flex items-center gap-2">
                  <input
                    type="radio"
                    name="executionPolicy"
                    value={policy}
                    checked={executionPolicy === policy}
                    onChange={(e) => {
                      setExecutionPolicy(e.target.value);
                      saveSetting('executionPolicy', e.target.value);
                    }}
                    className="radio"
                  />
                  <span className="text-text-primary">{policy}</span>
                </label>
              ))}
            </div>
          </div>

          <div>
            <label className="block text-sm text-text-secondary mb-2">Extra Flags</label>
            <div className="space-y-2">
              {[
                { key: 'NonInteractive', label: '-NonInteractive' },
                { key: 'NoProfile', label: '-NoProfile' },
                { key: 'WindowStyleHidden', label: '-WindowStyle Hidden' }
              ].map(flag => (
                <label key={flag.key} className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    checked={extraFlags[flag.key]}
                    onChange={(e) => {
                      const newFlags = { ...extraFlags, [flag.key]: e.target.checked };
                      setExtraFlags(newFlags);
                      saveSetting('extraFlags', JSON.stringify(newFlags));
                    }}
                    className="checkbox"
                  />
                  <span className="text-text-primary">{flag.label}</span>
                </label>
              ))}
            </div>
          </div>

          <div className="flex items-center justify-between pt-2 border-t border-border">
            <button onClick={testPowerShell} disabled={loading} className="btn-secondary">
              <RefreshCw className="w-4 h-4 mr-2" />
              Test PowerShell
            </button>
            {psTestResult && (
              <div className={`flex items-center gap-1 text-sm ${psTestResult.ok ? 'text-severity-low' : 'text-severity-critical'}`}>
                {psTestResult.ok ? (
                  <CheckCircle className="w-4 h-4" />
                ) : (
                  <AlertTriangle className="w-4 h-4" />
                )}
                <span>{psTestResult.message}</span>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* C# Compiler Settings */}
      <div className="card">
        <div className="flex items-center gap-2 mb-4">
          <SvgIcon name="system-settings" size={20} className="text-accent-primary" />
          <h3 className="font-semibold text-text-primary">C# Compiler</h3>
        </div>

        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <button onClick={detectCscPath} disabled={loading} className="btn-secondary">
              <RefreshCw className="w-4 h-4 mr-2" />
              Auto-detect csc.exe
            </button>
          </div>

          <div>
            <label className="block text-sm text-text-secondary mb-2">Manual csc.exe path</label>
            <input
              type="text"
              value={cscPath}
              onChange={(e) => {
                setCscPath(e.target.value);
                saveSetting('cscPath', e.target.value);
              }}
              placeholder="C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
              className="input"
            />
          </div>

          <div>
            <label className="block text-sm text-text-secondary mb-2">.NET SDK (dotnet) path</label>
            <input
              type="text"
              value={dotnetPath}
              onChange={(e) => {
                setDotnetPath(e.target.value);
                saveSetting('dotnetPath', e.target.value);
              }}
              placeholder="C:\Program Files\dotnet\dotnet.exe"
              className="input"
            />
          </div>
        </div>
      </div>

      {/* Database Settings */}
      <div className="card">
        <div className="flex items-center gap-2 mb-4">
          <Database className="w-5 h-5 text-accent-primary" />
          <h3 className="font-semibold text-text-primary">Database</h3>
        </div>

        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <span className="text-text-primary">Current DB size</span>
            <span className="font-mono text-accent-primary">{formatBytes(dbSize)}</span>
          </div>

          <div className="flex gap-2">
            <button onClick={exportDatabase} disabled={loading} className="btn-secondary">
              Export DB as JSON
            </button>
          </div>

          <div className="flex items-center gap-4">
            <label className="text-text-primary">Clear history older than:</label>
            <select
              value={clearHistoryDays}
              onChange={(e) => setClearHistoryDays(parseInt(e.target.value))}
              className="select"
            >
              <option value={7}>7 days</option>
              <option value={30}>30 days</option>
              <option value={90}>90 days</option>
              <option value={365}>1 year</option>
            </select>
            <button onClick={clearHistory} disabled={loading} className="btn-secondary">
              Apply
            </button>
          </div>

          <div className="border-t border-border pt-4">
            <button onClick={resetAllData} disabled={loading} className="btn-secondary bg-red-500 hover:bg-red-600 text-white">
              Reset all data (danger)
            </button>
          </div>
        </div>
      </div>

      {/* Appearance Settings */}
      <div className="card">
        <div className="flex items-center gap-2 mb-4">
          <Palette className="w-5 h-5 text-accent-primary" />
          <h3 className="font-semibold text-text-primary">Appearance</h3>
        </div>

        <div className="space-y-4">
          <div>
            <label className="block text-sm text-text-secondary mb-2">Table density</label>
            <div className="flex gap-2">
              {['comfortable', 'compact'].map(density => (
                <label key={density} className="flex items-center gap-2">
                  <input
                    type="radio"
                    name="tableDensity"
                    value={density}
                    checked={tableDensity === density}
                    onChange={(e) => {
                      setTableDensity(e.target.value);
                      saveSetting('tableDensity', e.target.value);
                    }}
                    className="radio"
                  />
                  <span className="text-text-primary capitalize">{density}</span>
                </label>
              ))}
            </div>
          </div>

          <div>
            <label className="block text-sm text-text-secondary mb-2">
              Terminal font size: {terminalFontSize}px
            </label>
            <input
              type="range"
              min="10"
              max="18"
              value={terminalFontSize}
              onChange={(e) => {
                const size = parseInt(e.target.value);
                setTerminalFontSize(size);
                saveSetting('terminalFontSize', size.toString());
              }}
              className="w-full"
            />
            <div className="flex justify-between text-xs text-text-muted">
              <span>10px</span>
              <span>18px</span>
            </div>
          </div>
        </div>
      </div>

      {/* About */}
      <div className="card">
        <div className="flex items-center gap-2 mb-4">
          <Info className="w-5 h-5 text-accent-primary" />
          <h3 className="font-semibold text-text-primary">About</h3>
        </div>

        <div className="space-y-2 text-sm">
          <div className="flex justify-between">
            <span className="text-text-secondary">Version:</span>
            <span className="text-text-primary">1.0.0</span>
          </div>
          <div className="flex justify-between">
            <span className="text-text-secondary">Total Checks:</span>
            <span className="text-text-primary">775</span>
          </div>
          <div className="flex justify-between">
            <span className="text-text-secondary">Categories:</span>
            <span className="text-text-primary">27</span>
          </div>
          <div className="flex justify-between">
            <span className="text-text-secondary">Engines:</span>
            <span className="text-text-primary">5</span>
          </div>
        </div>

        <div className="mt-4 pt-4 border-t border-border">
          <button disabled className="btn-secondary opacity-50">
            <RefreshCw className="w-4 h-4 mr-2" />
            Check for updates
          </button>
          <p className="text-xs text-text-muted mt-2">Update checking not implemented in demo</p>
        </div>
      </div>

    </div>
  );
};

export default Settings;
