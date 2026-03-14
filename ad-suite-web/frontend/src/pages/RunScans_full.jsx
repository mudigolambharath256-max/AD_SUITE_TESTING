import React, { useState } from 'react';
import { Shield, Play, Square, Download, AlertTriangle, CheckCircle, Zap, Search, Target, ZapOff } from 'lucide-react';
import { useScan } from '../hooks/useScan';
import CheckSelector from '../components/CheckSelector';
import EngineSelector from '../components/EngineSelector';
import ScanProgress from '../components/ScanProgress';
import FindingsTable from '../components/FindingsTable';
import { useAppStore } from '../store';

const RunScans = () => {
  const store = useAppStore();
  const { startScan, abortScan, resetScan, scanStatus, progress, findings, logLines, scanSummary, scanError, activeScanId } = useScan();

  const [validation, setValidation] = useState(null);
  const [targetValidation, setTargetValidation] = useState(null);

  // FQDN to DN conversion helper
  const fqdnToDN = (fqdn) => {
    return fqdn.split('.').map(part => `DC=${part}`).join(',');
  };

  // Connection mode badge logic
  const getConnectionMode = () => {
    if (store.serverIp && store.domain) {
      return { icon: Target, text: 'Explicit', desc: `LDAP://${store.serverIp}/${fqdnToDN(store.domain)}` };
    }
    if (store.serverIp && !store.domain) {
      return { icon: Zap, text: 'Direct', desc: `LDAP://${store.serverIp}/[auto-discovered NC]` };
    }
    if (!store.serverIp && store.domain) {
      return { icon: Search, text: 'Domain-targeted', desc: `LDAP://[DC from DNS]/${fqdnToDN(store.domain)}` };
    }
    return { icon: ZapOff, text: 'Auto-discover', desc: "uses machine's default domain (LDAP://RootDSE)" };
  };

  const validateDomain = (domain) => {
    if (!domain) return { valid: true };
    const regex = /^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$/;
    return {
      valid: regex.test(domain),
      error: regex.test(domain) ? null : 'Enter a valid FQDN (e.g. corp.domain.local)'
    };
  };

  const validateIP = (ip) => {
    if (!ip) return { valid: true };
    const ipv4Regex = /^(\d{1,3}\.){3}\d{1,3}$/;
    const ipv6Regex = /^[0-9a-fA-F:]+$/;
    const hostnameRegex = /^[a-zA-Z0-9][a-zA-Z0-9\-\.]+$/;
    return {
      valid: ipv4Regex.test(ip) || ipv6Regex.test(ip) || hostnameRegex.test(ip),
      error: 'Enter a valid IPv4 address, IPv6 address, or hostname'
    };
  };

  const testTarget = async () => {
    setTargetValidation({ loading: true });
    try {
      const response = await fetch('/api/scan/validate-target', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ domain: store.domain, serverIp: store.serverIp })
      });
      const result = await response.json();
      if (result.valid) {
        setTargetValidation({ valid: true, domainNC: result.domainNC });
      } else {
        setTargetValidation({ valid: false, error: result.error });
      }
    } catch (error) {
      setTargetValidation({ valid: false, error: error.message });
    }
  };

  const validateSuiteRoot = () => {
    if (!store.suiteRoot.trim()) {
      setValidation({ valid: false, error: 'Suite root path is required' });
      store.setSuiteRootValid(false);
      return;
    }

    const isValid = store.suiteRoot.includes('AD') || store.suiteRoot.includes('Security') || store.suiteRoot.length > 10;
    if (isValid) {
      setValidation({ valid: true, message: 'Suite root validated successfully' });
      store.setSuiteRootValid(true);
    } else {
      setValidation({ valid: false, error: 'Invalid suite root path' });
      store.setSuiteRootValid(false);
    }
  };

  const handleRunScan = async () => {
    if (store.selectedCheckIds.length === 0) {
      alert('Please select at least one check to run');
      return;
    }

    if (!store.suiteRootValid) {
      alert('Please validate suite root path before running scans');
      return;
    }

    if (store.engine === 'cmd' && (store.domain || store.serverIp)) {
      alert('Domain/IP targeting is not supported for CMD engine.\nSwitch to ADSI, PowerShell, or Combined for targeted scans.');
      return;
    }

    try {
      await startScan();
    } catch (error) {
      console.error('Failed to start scan:', error);
      alert(`Failed to start scan: ${error.message}`);
    }
  };

  const handleAbortScan = async () => {
    try {
      await abortScan();
    } catch (error) {
      console.error('Failed to abort scan:', error);
      alert(`Failed to abort scan: ${error.message}`);
    }
  };

  const handleNewScan = () => {
    resetScan();
  };

  const handleExport = async (format) => {
    if (!activeScanId) return;

    try {
      const response = await fetch('/api/reports/export', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ scanId: activeScanId, format })
      });

      if (!response.ok) throw new Error('Export failed');

      const blob = await response.blob();
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `ad-suite-scan-${activeScanId}.${format}`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      window.URL.revokeObjectURL(url);
    } catch (error) {
      console.error('Export failed:', error);
      alert(`Export failed: ${error.message}`);
    }
  };

  return (
    <div className="p-6">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-3xl font-bold text-text-primary mb-2">Run Scans</h1>
          <p className="text-text-secondary">Execute security checks against Active Directory</p>
        </div>
        {scanStatus !== 'idle' && (
          <button onClick={handleNewScan} className="btn-secondary">
            New Scan
          </button>
        )}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left Panel - Configuration */}
        <div className="lg:col-span-1 space-y-4">
          {/* Suite Root Path */}
          <div className="card">
            <h3 className="font-semibold text-text-primary mb-3">Suite Root Path</h3>
            <div className="space-y-2">
              <input
                type="text"
                placeholder="C:\\ADSuite\\AD-Suite-scripts-main"
                value={store.suiteRoot}
                onChange={(e) => store.setSuiteRoot(e.target.value)}
                className={`input ${store.suiteRootValid ? 'border-severity-low' : ''}`}
                disabled={!!activeScanId}
              />
              <div className="flex gap-2">
                <button
                  onClick={validateSuiteRoot}
                  disabled={!!activeScanId}
                  className="btn-secondary text-sm"
                >
                  Validate
                </button>
                {validation && (
                  <div className={`flex items-center gap-1 text-sm ${validation.valid ? 'text-severity-low' : 'text-severity-critical'
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

          {/* Target Configuration */}
          <div className="card">
            <h3 className="text-text-secondary text-xs uppercase tracking-wider mb-3">Target Configuration</h3>
            <div className="space-y-3">
              {/* Domain Name */}
              <div>
                <label className="block text-sm text-text-secondary mb-2">Domain Name (FQDN)</label>
                <div className="space-y-2">
                  <input
                    type="text"
                    placeholder="domain.local  or  america.corp.contoso.com"
                    value={store.domain}
                    onChange={(e) => store.setDomain(e.target.value)}
                    className={`input font-mono ${validateDomain(store.domain).valid ? '' : 'border-severity-critical'}`}
                    disabled={!!activeScanId}
                  />
                  <p className="text-text-muted text-xs mt-1">
                    Leave blank to auto-discover from machine running this app
                  </p>
                  {store.domain && validateDomain(store.domain).valid && (
                    <div className="bg-bg-tertiary rounded px-2 py-1 text-xs text-text-secondary mt-1">
                      {fqdnToDN(store.domain)}
                    </div>
                  )}
                  {store.domain && !validateDomain(store.domain).valid && (
                    <p className="text-severity-critical text-xs mt-1">
                      Enter a valid FQDN (e.g. corp.domain.local)
                    </p>
                  )}
                </div>
              </div>

              {/* Server IP */}
              <div>
                <label className="block text-sm text-text-secondary mb-2">DC / Server IP Address</label>
                <div className="space-y-2">
                  <input
                    type="text"
                    placeholder="192.168.1.10  or  10.0.0.5"
                    value={store.serverIp}
                    onChange={(e) => store.setServerIp(e.target.value)}
                    className={`input font-mono ${validateIP(store.serverIp).valid ? '' : 'border-severity-critical'}`}
                    disabled={!!activeScanId}
                  />
                  <p className="text-text-muted text-xs mt-1">
                    Optional. Targets a specific domain controller or domain-joined machine.
                    Bypasses DNS — useful for cross-domain or network-segmented scans.
                  </p>
                  {store.serverIp && !validateIP(store.serverIp).valid && (
                    <p className="text-severity-critical text-xs mt-1">
                      Enter a valid IPv4 address, IPv6 address, or hostname
                    </p>
                  )}
                </div>
              </div>

              {/* Connection Mode Badge */}
              {(store.domain || store.serverIp) && (
                <div className="flex items-center gap-2 px-3 py-2 bg-bg-tertiary rounded-lg">
                  {(() => {
                    const mode = getConnectionMode();
                    const Icon = mode.icon;
                    return (
                      <>
                        <Icon className="w-4 h-4" />
                        <span className="text-sm">
                          {mode.text} — {mode.desc}
                        </span>
                      </>
                    );
                  })()}
                </div>
              )}

              {/* Test Target Button */}
              {(store.domain || store.serverIp) && (
                <div className="flex gap-2">
                  <button
                    onClick={testTarget}
                    disabled={targetValidation?.loading || !!activeScanId}
                    className="btn-secondary text-sm"
                  >
                    {targetValidation?.loading ? 'Testing...' : 'Test Connection'}
                  </button>
                  {targetValidation && !targetValidation.loading && (
                    <div className={`flex items-center gap-1 text-sm px-2 py-1 rounded ${targetValidation.valid ? 'bg-severity-low/20 text-severity-low' : 'bg-severity-critical/20 text-severity-critical'
                      }`}>
                      {targetValidation.valid ? '✓' : '✗'} {targetValidation.valid ?
                        `Connected — ${targetValidation.domainNC}` :
                        `Cannot connect: ${targetValidation.error}`
                      }
                    </div>
                  )}
                </div>
              )}
            </div>
          </div>

          {/* Engine Selector */}
          <div className="card">
            <h3 className="font-semibold text-text-primary mb-3">Execution Engine</h3>
            <EngineSelector
              selectedEngine={store.engine}
              onEngineChange={(engine) => store.setEngine(engine)}
              disabled={!!activeScanId}
            />
          </div>

          {/* Check Selector */}
          <div className="card">
            <h3 className="font-semibold text-text-primary mb-3">Select Checks</h3>
            <CheckSelector
              selectedChecks={store.selectedCheckIds}
              onSelectionChange={(checks) => store.setSelectedCheckIds(checks)}
              disabled={!!activeScanId}
            />
          </div>
        </div>

        {/* Right Panel - Execution & Results */}
        <div className="lg:col-span-2 space-y-4">
          {scanStatus === 'idle' && (
            <div className="card">
              <div className="text-center py-12">
                <Shield className="w-16 h-16 mx-auto text-text-muted mb-4" />
                <h3 className="text-xl font-semibold text-text-primary mb-2">Ready to Scan</h3>
                <p className="text-text-secondary mb-6">
                  Configure your scan settings and click Run Scan to begin
                </p>
                <button
                  onClick={handleRunScan}
                  disabled={!store.suiteRootValid || store.selectedCheckIds.length === 0}
                  className="btn-primary inline-flex items-center gap-2"
                >
                  <Play className="w-4 h-4" />
                  Run Scan
                </button>
              </div>
            </div>
          )}

          {scanStatus === 'running' && (
            <>
              <div className="card">
                <div className="flex items-center justify-between mb-4">
                  <h3 className="font-semibold text-text-primary">Scan in Progress</h3>
                  <button
                    onClick={handleAbortScan}
                    className="btn-danger inline-flex items-center gap-2"
                  >
                    <Square className="w-4 h-4" />
                    Abort Scan
                  </button>
                </div>
                <ScanProgress
                  scan={{ status: scanStatus, id: activeScanId }}
                  progress={progress}
                  logs={logLines}
                />
              </div>

              {/* Live Log */}
              <div className="card">
                <h3 className="font-semibold text-text-primary mb-3">Execution Log</h3>
                <div className="bg-bg-tertiary rounded p-3 font-mono text-xs text-text-secondary max-h-64 overflow-y-auto">
                  {logLines.length === 0 ? (
                    <div className="text-text-muted">Waiting for output...</div>
                  ) : (
                    logLines.map((log, i) => (
                      <div key={i}>{log.line}</div>
                    ))
                  )}
                </div>
              </div>
            </>
          )}

          {(scanStatus === 'complete' || scanStatus === 'error' || scanStatus === 'aborted') && (
            <>
              <div className="card">
                <div className="flex items-center justify-between mb-4">
                  <div>
                    <h3 className="font-semibold text-text-primary">
                      {scanStatus === 'complete' && 'Scan Complete'}
                      {scanStatus === 'error' && 'Scan Failed'}
                      {scanStatus === 'aborted' && 'Scan Aborted'}
                    </h3>
                    {scanSummary && (
                      <p className="text-sm text-text-secondary mt-1">
                        {scanSummary.total} findings in {scanSummary.duration}
                      </p>
                    )}
                    {scanError && (
                      <p className="text-sm text-severity-critical mt-1">{scanError}</p>
                    )}
                  </div>
                  <div className="flex gap-2">
                    <button
                      onClick={() => handleExport('json')}
                      className="btn-secondary inline-flex items-center gap-2"
                    >
                      <Download className="w-4 h-4" />
                      JSON
                    </button>
                    <button
                      onClick={() => handleExport('csv')}
                      className="btn-secondary inline-flex items-center gap-2"
                    >
                      <Download className="w-4 h-4" />
                      CSV
                    </button>
                  </div>
                </div>

                {scanSummary && (
                  <div className="grid grid-cols-4 gap-4 mb-4">
                    <div className="bg-severity-critical/10 rounded p-3">
                      <div className="text-2xl font-bold text-severity-critical">
                        {scanSummary.bySeverity?.Critical || 0}
                      </div>
                      <div className="text-xs text-text-secondary">Critical</div>
                    </div>
                    <div className="bg-severity-high/10 rounded p-3">
                      <div className="text-2xl font-bold text-severity-high">
                        {scanSummary.bySeverity?.High || 0}
                      </div>
                      <div className="text-xs text-text-secondary">High</div>
                    </div>
                    <div className="bg-severity-medium/10 rounded p-3">
                      <div className="text-2xl font-bold text-severity-medium">
                        {scanSummary.bySeverity?.Medium || 0}
                      </div>
                      <div className="text-xs text-text-secondary">Medium</div>
                    </div>
                    <div className="bg-severity-low/10 rounded p-3">
                      <div className="text-2xl font-bold text-severity-low">
                        {scanSummary.bySeverity?.Low || 0}
                      </div>
                      <div className="text-xs text-text-secondary">Low</div>
                    </div>
                  </div>
                )}
              </div>

              {findings.length > 0 && (
                <div className="card">
                  <h3 className="font-semibold text-text-primary mb-3">Findings</h3>
                  <FindingsTable
                    findings={findings}
                    loading={false}
                    filters={{}}
                    onFiltersChange={() => { }}
                  />
                </div>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  );
};

export default RunScans;
