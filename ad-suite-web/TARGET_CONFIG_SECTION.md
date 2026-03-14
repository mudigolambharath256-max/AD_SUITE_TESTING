# Target Configuration Section for RunScans.jsx

Add this section after the Suite Root Path card and before the Engine Selector:

```jsx
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
          className={`input font-mono ${validateDomain(store.domain).valid ? '' : 'input-error'}`}
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
          className={`input font-mono ${validateIP(store.serverIp).valid ? '' : 'input-error'}`}
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
          <div className={`flex items-center gap-1 text-sm px-2 py-1 rounded ${
            targetValidation.valid ? 'bg-severity-low/20 text-severity-low' : 'bg-severity-critical/20 text-severity-critical'
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
```

## Helper Functions to Add

Add these at the top of the RunScans component:

```jsx
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
```

## State Variables Needed

Replace local state with:

```jsx
const store = useAppStore();
const { startScan, abortScan, resetScan, scanStatus, progress, findings, logLines, scanSummary, scanError, activeScanId } = useScan();
const [validation, setValidation] = useState(null);
const [targetValidation, setTargetValidation] = useState(null);
```

## Implementation Status

✅ Backend fully implemented with domain/IP injection
✅ Database migration complete
✅ Zustand stores created and configured
✅ useScan hook updated
✅ App.jsx updated with reconnection logic
⚠️ RunScans.jsx needs UI updates (backend integration works)
⚠️ Other pages need store integration

The application is functional - scans can be run and the backend will properly inject domain/IP when provided via API. The UI just needs the input fields added to RunScans.jsx.
