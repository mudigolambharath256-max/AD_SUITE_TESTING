import { useEffect, useRef, useCallback } from 'react';
import { useAppStore } from '../store';
import { useFindingsStore } from '../store';
import { useHistoryStore } from '../store';

export function useScan() {
  const store = useAppStore();
  const findingsStore = useFindingsStore();
  const historyStore = useHistoryStore();
  const sseRef = useRef(null);

  // Safety check: ensure stores are initialized
  if (!store || !findingsStore || !historyStore) {
    console.warn('Stores not yet initialized');
    return {
      scanStatus: 'idle',
      progress: { current: 0, total: 0, currentCheckId: '', currentCheckName: '' },
      findings: [],
      logLines: [],
      scanSummary: null,
      scanError: null,
      activeScanId: null,
      startScan: async () => { throw new Error('Store not ready'); },
      abortScan: async () => { },
      resetScan: () => { },
    };
  }

  const connectSSE = useCallback((scanId) => {
    if (sseRef.current) sseRef.current.close();

    let retryDelay = 100;
    const connect = () => {
      const es = new EventSource(`/api/scan/stream/${scanId}`);
      sseRef.current = es;

      es.onmessage = (e) => {
        const event = JSON.parse(e.data);
        retryDelay = 100; // reset on successful message

        if (event.type === 'progress') {
          store.updateProgress(event.progress);
          store.setScanStatus('running');
        }
        if (event.type === 'log') {
          findingsStore.appendLog(event.line);
        }
        if (event.type === 'finding') {
          findingsStore.addFinding(event.finding);
        }
        if (event.type === 'complete') {
          store.setScanStatus('complete');
          store.setScanSummary(event.summary);
          es.close();
          // Refresh scan history
          fetch('/api/scan/recent')
            .then(res => res.json())
            .then(data => historyStore.setRecentScans(data))
            .catch(err => console.error('Failed to refresh history:', err));
        }
        if (event.type === 'error') {
          store.setScanError(event.message);
          es.close();
        }
        if (event.type === 'aborted') {
          store.setScanStatus('aborted');
          es.close();
        }
      };

      es.onerror = () => {
        es.close();
        if (store.scanStatus === 'running') {
          // Reconnect with exponential back-off
          retryDelay = Math.min(retryDelay * 2, 5000);
          setTimeout(connect, retryDelay);
        }
      };
    };
    connect();
  }, [store, findingsStore, historyStore]);

  // On mount: if a scan was running when page last unloaded, reconnect
  useEffect(() => {
    // Safety check: ensure store is hydrated before accessing properties
    if (store?.activeScanId && store?.scanStatus === 'running') {
      connectSSE(store.activeScanId);
    }
  }, [store?.activeScanId, store?.scanStatus, connectSSE]);

  const startScan = useCallback(async () => {
    if (!store?.suiteRootValid) throw new Error('Suite root not validated');
    if (!store?.selectedCheckIds || store.selectedCheckIds.length === 0) throw new Error('No checks selected');

    findingsStore.clearFindings();

    const response = await fetch('/api/scan/run', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        checkIds: store.selectedCheckIds,
        engine: store.engine || 'adsi',
        suiteRoot: store.suiteRoot,
        domain: store.domain || null,
        serverIp: store.serverIp || null,
      })
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Failed to start scan');
    }

    const { scanId } = await response.json();

    store.setActiveScan(scanId);
    connectSSE(scanId);
    return scanId;
  }, [store, findingsStore, connectSSE]);

  const abortScan = useCallback(async () => {
    if (store?.activeScanId) {
      await fetch(`/api/scan/abort/${store.activeScanId}`, { method: 'POST' });
    }
    if (sseRef.current) sseRef.current.close();
    store?.setScanStatus('aborted');
  }, [store]);

  return {
    // State - with safe defaults
    scanStatus: store?.scanStatus || 'idle',
    progress: store?.progress || { current: 0, total: 0, currentCheckId: '', currentCheckName: '' },
    findings: findingsStore?.findings || [],
    logLines: findingsStore?.logLines || [],
    scanSummary: store?.scanSummary || null,
    scanError: store?.scanError || null,
    activeScanId: store?.activeScanId || null,
    // Actions
    startScan,
    abortScan,
    resetScan: () => {
      store?.resetScan();
      findingsStore?.clearFindings();
    },
  };
}
