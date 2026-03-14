import React, { useState, useEffect } from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import Sidebar from './components/Sidebar';
import Dashboard from './pages/Dashboard';
import RunScans from './pages/RunScans';
import AttackPath from './pages/AttackPath';
import Integrations from './pages/Integrations';
import Reports from './pages/Reports';
import Settings from './pages/Settings';
import { getHealth } from './lib/api';
import { useAppStore, useFindingsStore } from './store';

function App() {
  const [isSidebarCollapsed, setIsSidebarCollapsed] = useState(false);
  const [health, setHealth] = useState(null);
  const [healthError, setHealthError] = useState(null);

  useEffect(() => {
    const checkHealth = async () => {
      try {
        const healthData = await getHealth();
        setHealth(healthData);
        setHealthError(null);
      } catch (error) {
        console.error('Health check failed:', error);
        setHealthError(error.message);
      }
    };

    checkHealth();
    const interval = setInterval(checkHealth, 30000); // Check every 30 seconds
    return () => clearInterval(interval);
  }, []);

  // Stale scan reconnect logic
  useEffect(() => {
    const { activeScanId, scanStatus, setScanStatus } = useAppStore.getState();
    const { setFindings } = useFindingsStore.getState();

    if (activeScanId && scanStatus === 'running') {
      // App reloaded during an active scan.
      // Check if the scan is still running on the backend.
      fetch(`/api/scan/status/${activeScanId}`)
        .then(res => res.json())
        .then(data => {
          if (data.status === 'running') {
            // Still running — useScan hook will reconnect SSE on the /scans page
            console.log('Scan is still running. Go to Run Scans to monitor progress.');
          } else if (data.status === 'completed') {
            // Completed while we were away — fetch findings
            setScanStatus('complete');
            fetch(`/api/scan/${activeScanId}/findings?limit=5000`)
              .then(res => res.json())
              .then(res => {
                setFindings(res.findings || []);
              })
              .catch(err => console.error('Failed to load findings:', err));
          } else {
            // Failed/aborted — update status
            setScanStatus(data.status);
          }
        })
        .catch(() => {
          // Backend not available or scan ID not found — reset
          setScanStatus('idle');
        });
    }
  }, []);

  const toggleSidebar = () => {
    setIsSidebarCollapsed(!isSidebarCollapsed);
  };

  return (
    <div className="min-h-screen bg-bg-primary flex">
      {/* Sidebar */}
      <Sidebar
        isCollapsed={isSidebarCollapsed}
        onToggle={toggleSidebar}
      />

      {/* Main Content */}
      <div className={`flex-1 transition-all duration-300 ${isSidebarCollapsed ? 'ml-12' : 'ml-60'}`}>
        {/* Health Status Banner */}
        {healthError && (
          <div className="bg-severity-critical/10 border-b border-severity-critical/30 p-3">
            <div className="flex items-center gap-2 text-severity-critical">
              <span className="font-medium">Backend Connection Failed:</span>
              <span>{healthError}</span>
            </div>
          </div>
        )}

        {/* Routes */}
        <Routes>
          <Route path="/" element={<Dashboard />} />
          <Route path="/scans" element={<RunScans />} />
          <Route path="/attack-path" element={<AttackPath />} />
          <Route path="/integrations" element={<Integrations />} />
          <Route path="/reports" element={<Reports />} />
          <Route path="/settings" element={<Settings />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </div>

      {/* Mobile Menu Toggle */}
      <button
        onClick={toggleSidebar}
        className="lg:hidden fixed top-4 left-4 z-50 w-10 h-10 bg-accent-primary text-bg-primary rounded-full flex items-center justify-center shadow-lg active-scale"
      >
        <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
        </svg>
      </button>
    </div>
  );
}

export default App;
