import React, { useState, useEffect } from 'react';
import {
  FileText,
  Download,
  Calendar,
  Filter,
  Search,
  X,
  CheckCircle,
  Clock,
  AlertTriangle,
  Eye,
  Trash2,
  Settings
} from 'lucide-react';
import { getRecentScans, getFindings, exportScan, exportMultipleScans } from '../lib/api';
import FindingsTable from '../components/FindingsTable';
import { getSeverityColor } from '../lib/colours';

const Reports = () => {
  const [scans, setScans] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [selectedScans, setSelectedScans] = useState(new Set());
  const [expandedScan, setExpandedScan] = useState(null);
  const [scanFindings, setScanFindings] = useState({});
  const [loadingFindings, setLoadingFindings] = useState({});

  // Filter state
  const [filters, setFilters] = useState({
    dateRange: { start: '', end: '' },
    severity: [],
    category: [],
    engine: [],
    search: ''
  });
  const [showFilters, setShowFilters] = useState(false);

  useEffect(() => {
    loadScans();
  }, []);

  const loadScans = async () => {
    try {
      setLoading(true);
      const scansData = await getRecentScans(100); // Get more for reports
      setScans(scansData);
    } catch (error) {
      console.error('Failed to load scans:', error);
      setError(error.message);
    } finally {
      setLoading(false);
    }
  };

  const loadScanFindings = async (scanId) => {
    if (scanFindings[scanId]) return; // Already loaded

    setLoadingFindings(prev => ({ ...prev, [scanId]: true }));
    try {
      const response = await getFindings(scanId, 1, 100);
      setScanFindings(prev => ({ ...prev, [scanId]: response.findings }));
    } catch (error) {
      console.error('Failed to load findings:', error);
    } finally {
      setLoadingFindings(prev => ({ ...prev, [scanId]: false }));
    }
  };

  const toggleScanSelection = (scanId) => {
    const newSelection = new Set(selectedScans);
    if (newSelection.has(scanId)) {
      newSelection.delete(scanId);
    } else {
      newSelection.add(scanId);
    }
    setSelectedScans(newSelection);
  };

  const toggleAllScans = () => {
    if (selectedScans.size === scans.length) {
      setSelectedScans(new Set());
    } else {
      setSelectedScans(new Set(scans.map(scan => scan.id)));
    }
  };

  const toggleScanExpansion = async (scanId) => {
    if (expandedScan === scanId) {
      setExpandedScan(null);
    } else {
      setExpandedScan(scanId);
      await loadScanFindings(scanId);
    }
  };

  const exportSingleScan = async (scanId, format) => {
    try {
      const blob = await exportScan(scanId, format);
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `ad-suite-scan-${scanId}.${format}`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      window.URL.revokeObjectURL(url);
    } catch (error) {
      console.error('Export failed:', error);
      alert(`Export failed: ${error.message}`);
    }
  };

  const exportMultiple = async (format) => {
    if (selectedScans.size === 0) {
      alert('Please select scans to export');
      return;
    }

    try {
      const scanIds = Array.from(selectedScans);
      const blob = await exportMultipleScans(scanIds, format);
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `ad-suite-merged-${Date.now()}.${format}`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      window.URL.revokeObjectURL(url);
    } catch (error) {
      console.error('Export failed:', error);
      alert(`Export failed: ${error.message}`);
    }
  };

  const deleteSelectedScans = async () => {
    if (selectedScans.size === 0) return;

    if (!confirm(`Are you sure you want to delete ${selectedScans.size} scan(s)? This action cannot be undone.`)) {
      return;
    }

    try {
      const scanIds = Array.from(selectedScans);
      const response = await fetch('/api/reports/delete', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ scanIds })
      });

      const result = await response.json();

      if (result.deleted) {
        alert(`Successfully deleted ${result.scansDeleted} scan(s) and ${result.findingsDeleted} finding(s)`);
        setSelectedScans(new Set());
        await loadScans(); // Reload the scan list
      } else {
        alert('Failed to delete scans');
      }
    } catch (error) {
      console.error('Delete failed:', error);
      alert(`Delete failed: ${error.message}`);
    }
  };

  const getStatusIcon = (status) => {
    switch (status) {
      case 'running':
        return <Clock className="w-4 h-4 animate-pulse text-blue-500" />;
      case 'completed':
        return <CheckCircle className="w-4 h-4 text-green-500" />;
      case 'failed':
        return <AlertTriangle className="w-4 h-4 text-red-500" />;
      default:
        return <Clock className="w-4 h-4 text-gray-500" />;
    }
  };

  const formatDuration = (duration) => {
    if (!duration) return 'N/A';
    const seconds = Math.round(duration / 1000);
    if (seconds < 60) return `${seconds}s`;
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = seconds % 60;
    return `${minutes}m ${remainingSeconds}s`;
  };

  const clearFilters = () => {
    setFilters({
      dateRange: { start: '', end: '' },
      severity: [],
      category: [],
      engine: [],
      search: ''
    });
  };

  const filteredScans = scans.filter(scan => {
    // Search filter
    if (filters.search && !scan.id.toLowerCase().includes(filters.search.toLowerCase())) {
      return false;
    }

    // Engine filter
    if (filters.engine.length > 0 && !filters.engine.includes(scan.engine)) {
      return false;
    }

    // Date range filter
    if (filters.dateRange.start) {
      const scanDate = new Date(scan.timestamp);
      const startDate = new Date(filters.dateRange.start);
      if (scanDate < startDate) return false;
    }
    if (filters.dateRange.end) {
      const scanDate = new Date(scan.timestamp);
      const endDate = new Date(filters.dateRange.end);
      endDate.setHours(23, 59, 59, 999);
      if (scanDate > endDate) return false;
    }

    return true;
  });

  if (loading) {
    return (
      <div className="p-6 space-y-6">
        <div className="skeleton h-8 w-48"></div>
        <div className="skeleton h-96"></div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-6">
        <div className="card">
          <div className="flex items-center gap-3 text-severity-critical">
            <AlertTriangle className="w-6 h-6" />
            <h3 className="text-lg font-semibold">Error Loading Reports</h3>
          </div>
          <p className="text-text-secondary mt-2">{error}</p>
          <button onClick={loadScans} className="btn-primary mt-4">
            Retry
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-text-primary mb-2">Reports</h1>
        <p className="text-text-secondary">View, filter, and export security scan results</p>
      </div>

      {/* Filter Bar */}
      <div className="card">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-2">
            <Filter className="w-4 h-4 text-text-secondary" />
            <span className="font-medium text-text-primary">Filters</span>
          </div>
          <button
            onClick={() => setShowFilters(!showFilters)}
            className="btn-secondary text-sm"
          >
            {showFilters ? 'Hide' : 'Show'} Filters
          </button>
        </div>

        {showFilters && (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <div>
              <label className="block text-sm text-text-secondary mb-1">From Date</label>
              <input
                type="date"
                value={filters.dateRange.start}
                onChange={(e) => setFilters(prev => ({
                  ...prev,
                  dateRange: { ...prev.dateRange, start: e.target.value }
                }))}
                className="input text-sm"
              />
            </div>
            <div>
              <label className="block text-sm text-text-secondary mb-1">To Date</label>
              <input
                type="date"
                value={filters.dateRange.end}
                onChange={(e) => setFilters(prev => ({
                  ...prev,
                  dateRange: { ...prev.dateRange, end: e.target.value }
                }))}
                className="input text-sm"
              />
            </div>
            <div>
              <label className="block text-sm text-text-secondary mb-1">Engine</label>
              <div className="flex flex-wrap gap-1">
                {['adsi', 'powershell', 'csharp', 'cmd', 'combined'].map(engine => (
                  <button
                    key={engine}
                    onClick={() => {
                      setFilters(prev => ({
                        ...prev,
                        engine: prev.engine.includes(engine)
                          ? prev.engine.filter(e => e !== engine)
                          : [...prev.engine, engine]
                      }));
                    }}
                    className={`text-xs px-2 py-1 rounded ${filters.engine.includes(engine)
                      ? 'bg-accent-primary text-bg-primary'
                      : 'bg-bg-tertiary text-text-secondary'
                      }`}
                  >
                    {engine}
                  </button>
                ))}
              </div>
            </div>
            <div>
              <label className="block text-sm text-text-secondary mb-1">Search</label>
              <div className="relative">
                <Search className="absolute left-2 top-1/2 transform -translate-y-1/2 w-3 h-3 text-text-muted" />
                <input
                  type="text"
                  placeholder="Scan ID..."
                  value={filters.search}
                  onChange={(e) => setFilters(prev => ({ ...prev, search: e.target.value }))}
                  className="input text-sm pl-8"
                />
              </div>
            </div>
          </div>
        )}

        <div className="flex items-center justify-between mt-4">
          <span className="text-sm text-text-secondary">
            {filteredScans.length} scan{filteredScans.length !== 1 ? 's' : ''} found
          </span>
          <button onClick={clearFilters} className="btn-secondary text-sm">
            Clear Filters
          </button>
        </div>
      </div>

      {/* Scan History Table */}
      <div className="card">
        <div className="flex items-center justify-between mb-4">
          <h3 className="font-semibold text-text-primary">Scan History</h3>
          <div className="flex items-center gap-2">
            <span className="text-sm text-text-secondary">
              {selectedScans.size} selected
            </span>
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="table">
            <thead>
              <tr>
                <th className="w-8">
                  <input
                    type="checkbox"
                    checked={selectedScans.size === filteredScans.length && filteredScans.length > 0}
                    onChange={toggleAllScans}
                    className="checkbox"
                  />
                </th>
                <th>Scan ID</th>
                <th>Date/Time</th>
                <th>Engine</th>
                <th>Checks</th>
                <th>Findings</th>
                <th>CRIT</th>
                <th>HIGH</th>
                <th>Duration</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredScans.map((scan) => (
                <React.Fragment key={scan.id}>
                  <tr>
                    <td>
                      <input
                        type="checkbox"
                        checked={selectedScans.has(scan.id)}
                        onChange={() => toggleScanSelection(scan.id)}
                        className="checkbox"
                      />
                    </td>
                    <td className="font-mono text-accent-primary text-sm">
                      {scan.id.substring(0, 8)}...
                    </td>
                    <td className="text-sm">
                      {new Date(scan.timestamp).toLocaleString()}
                    </td>
                    <td>
                      <span className="severity-badge severity-info">
                        {scan.engine.toUpperCase()}
                      </span>
                    </td>
                    <td>{scan.check_count}</td>
                    <td>{scan.finding_count}</td>
                    <td>-</td>
                    <td>-</td>
                    <td>{formatDuration(scan.duration_ms)}</td>
                    <td>
                      <div className="flex items-center gap-2">
                        {getStatusIcon(scan.status)}
                        <span className="text-sm capitalize">{scan.status}</span>
                      </div>
                    </td>
                    <td>
                      <div className="flex gap-1">
                        <button
                          onClick={() => toggleScanExpansion(scan.id)}
                          className="btn-secondary text-xs px-2 py-1"
                        >
                          <Eye className="w-3 h-3" />
                        </button>
                        <button
                          onClick={() => exportSingleScan(scan.id, 'json')}
                          className="btn-secondary text-xs px-2 py-1"
                        >
                          <Download className="w-3 h-3" />
                        </button>
                      </div>
                    </td>
                  </tr>

                  {expandedScan === scan.id && (
                    <tr>
                      <td colSpan="11" className="bg-bg-surface">
                        <div className="p-4">
                          <h4 className="font-medium text-text-primary mb-3">Scan Findings</h4>
                          {loadingFindings[scan.id] ? (
                            <div className="text-center py-8">
                              <div className="animate-spin w-6 h-6 border-2 border-accent-primary border-t-transparent rounded-full mx-auto"></div>
                              <p className="text-text-secondary mt-2">Loading findings...</p>
                            </div>
                          ) : (
                            <FindingsTable
                              findings={scanFindings[scan.id] || []}
                              loading={false}
                            />
                          )}
                        </div>
                      </td>
                    </tr>
                  )}
                </React.Fragment>
              ))}
            </tbody>
          </table>
        </div>

        {filteredScans.length === 0 && (
          <div className="text-center py-8 text-text-secondary">
            <FileText className="w-12 h-12 mx-auto mb-4 opacity-50" />
            <p>No scans found matching your filters</p>
          </div>
        )}
      </div>

      {/* Bulk Action Bar */}
      {selectedScans.size > 0 && (
        <div className="card bg-accent-muted/10 border border-accent-primary/30">
          <div className="flex items-center justify-between">
            <span className="text-text-primary">
              {selectedScans.size} scan{selectedScans.size !== 1 ? 's' : ''} selected
            </span>
            <div className="flex gap-2">
              <button
                onClick={() => exportMultiple('json')}
                className="btn-secondary text-sm"
              >
                <Download className="w-3 h-3 mr-1" />
                Download JSON
              </button>
              <button
                onClick={() => exportMultiple('csv')}
                className="btn-secondary text-sm"
              >
                <Download className="w-3 h-3 mr-1" />
                Download CSV
              </button>
              <button
                onClick={() => exportMultiple('pdf')}
                className="btn-secondary text-sm"
              >
                <Download className="w-3 h-3 mr-1" />
                Download PDF (merged)
              </button>
              <button
                onClick={deleteSelectedScans}
                className="btn-secondary text-sm bg-red-500 hover:bg-red-600 text-white"
              >
                <Trash2 className="w-3 h-3 mr-1" />
                Delete Selected
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Reports;
