import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import {
  Activity,
  AlertTriangle,
  CheckCircle,
  Clock,
  Play,
  TrendingUp,
  Eye,
  Download
} from 'lucide-react';
import { PieChart, Pie, Cell, ResponsiveContainer, BarChart, Bar, XAxis, YAxis, Tooltip, Legend } from 'recharts';
import { getSeveritySummary, getCategorySummary, getRecentScans } from '../lib/api';
import { chartColors } from '../lib/colours';
import SvgIcon from '../components/SvgIcon';

const Dashboard = () => {
  const [severityData, setSeverityData] = useState({});
  const [categoryData, setCategoryData] = useState([]);
  const [recentScans, setRecentScans] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const loadDashboardData = async () => {
      try {
        setLoading(true);
        setError(null);

        const [severity, categories, scans] = await Promise.all([
          getSeveritySummary(),
          getCategorySummary(),
          getRecentScans(10)
        ]);

        setSeverityData(severity);
        setCategoryData(categories);
        setRecentScans(scans);
      } catch (err) {
        console.error('Failed to load dashboard data:', err);
        setError(err.message);
      } finally {
        setLoading(false);
      }
    };

    loadDashboardData();
  }, []);

  // Transform severity data for pie chart
  const pieChartData = Object.entries(severityData).map(([severity, count]) => ({
    name: severity.toUpperCase(),
    value: count,
    color: chartColors[severity.toLowerCase()] || chartColors.info
  })).filter(item => item.value > 0);

  // Transform category data for bar chart
  const barChartData = categoryData.map(item => ({
    category: item.category.replace(/_/g, ' ').substring(0, 15) + (item.category.length > 15 ? '...' : ''),
    count: item.count,
    fullCategory: item.category
  })).slice(0, 8); // Top 8 categories

  const totalFindings = Object.values(severityData).reduce((sum, count) => sum + count, 0);
  const criticalFindings = severityData.critical || 0;

  const handleDownloadScan = async (scanId, format = 'json') => {
    try {
      const response = await fetch('http://localhost:3001/api/reports/export', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          scanIds: [scanId],
          format: format
        })
      });

      if (!response.ok) {
        throw new Error('Failed to download scan');
      }

      const blob = await response.blob();
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `scan_${scanId.substring(0, 8)}_findings.${format}`;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);
    } catch (error) {
      console.error('Download error:', error);
      alert('Failed to download scan: ' + error.message);
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

  if (loading) {
    return (
      <div className="p-6 space-y-6">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          {[...Array(4)].map((_, i) => (
            <div key={i} className="card skeleton h-32"></div>
          ))}
        </div>
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div className="card skeleton h-80"></div>
          <div className="card skeleton h-80"></div>
        </div>
        <div className="card skeleton h-96"></div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-6">
        <div className="card">
          <div className="flex items-center gap-3 text-severity-critical">
            <AlertTriangle className="w-6 h-6" />
            <h3 className="text-lg font-semibold">Error Loading Dashboard</h3>
          </div>
          <p className="text-text-secondary mt-2">{error}</p>
          <button
            onClick={() => window.location.reload()}
            className="btn-primary mt-4"
          >
            Retry
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="p-6 space-y-6 fade-in">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-text-primary mb-2">Dashboard</h1>
        <p className="text-text-secondary">AD Security Suite overview and recent activity</p>
      </div>

      {/* Stat Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <div className="card">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-text-secondary text-sm">Total Checks</p>
              <p className="text-3xl font-bold text-text-primary">775</p>
            </div>
            <SvgIcon name="all-covered" size={32} className="text-accent-primary" />
          </div>
        </div>

        <div className="card">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-text-secondary text-sm">Last Scan Findings</p>
              <p className="text-3xl font-bold text-text-primary">{totalFindings}</p>
            </div>
            <Activity className="w-8 h-8 text-accent-primary" />
          </div>
        </div>

        <div className="card">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-text-secondary text-sm">Critical Findings</p>
              <p className={`text-3xl font-bold ${criticalFindings > 0 ? 'text-severity-critical' : 'text-text-primary'}`}>
                {criticalFindings}
              </p>
            </div>
            <AlertTriangle className={`w-8 h-8 ${criticalFindings > 0 ? 'text-severity-critical' : 'text-accent-primary'}`} />
          </div>
        </div>

        <div className="card">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-text-secondary text-sm">Categories Scanned</p>
              <p className="text-3xl font-bold text-text-primary">{categoryData.length}</p>
            </div>
            <TrendingUp className="w-8 h-8 text-accent-primary" />
          </div>
        </div>
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Severity Pie Chart */}
        <div className="card">
          <h3 className="text-lg font-semibold text-text-primary mb-4">Findings by Severity</h3>
          {pieChartData.length > 0 ? (
            <ResponsiveContainer width="100%" height={300}>
              <PieChart>
                <Pie
                  data={pieChartData}
                  cx="50%"
                  cy="50%"
                  labelLine={false}
                  label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
                  outerRadius={80}
                  fill="#8b6db5"
                  dataKey="value"
                >
                  {pieChartData.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={entry.color} />
                  ))}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          ) : (
            <div className="h-64 flex items-center justify-center text-text-secondary">
              No findings data available
            </div>
          )}
        </div>

        {/* Category Bar Chart */}
        <div className="card">
          <h3 className="text-lg font-semibold text-text-primary mb-4">Checks Run by Category</h3>
          {barChartData.length > 0 ? (
            <ResponsiveContainer width="100%" height={300}>
              <BarChart data={barChartData}>
                <XAxis
                  dataKey="category"
                  tick={{ fill: '#9b8e7e', fontSize: 12 }}
                  angle={-45}
                  textAnchor="end"
                  height={60}
                />
                <YAxis tick={{ fill: '#9b8e7e' }} />
                <Tooltip
                  contentStyle={{
                    backgroundColor: '#262220',
                    border: '1px solid #3d3530',
                    borderRadius: '8px'
                  }}
                  labelStyle={{ color: '#ede9e0' }}
                  formatter={(value) => [value, 'Checks']}
                  labelFormatter={(label) => {
                    const item = barChartData.find(d => d.category === label);
                    return item?.fullCategory || label;
                  }}
                />
                <Bar dataKey="count" fill="#d4a96a" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          ) : (
            <div className="h-64 flex items-center justify-center text-text-secondary">
              No category data available
            </div>
          )}
        </div>
      </div>

      {/* Recent Scans Table */}
      <div className="card">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-semibold text-text-primary">Recent Scans</h3>
          <div className="flex gap-2">
            {recentScans.length > 0 && (
              <button
                onClick={() => handleDownloadScan(recentScans[0].id, 'json')}
                className="btn-primary text-sm flex items-center gap-2"
                title="Download most recent scan"
              >
                <Download className="w-4 h-4" />
                Download Latest
              </button>
            )}
            <Link to="/reports" className="btn-secondary text-sm">
              View All
            </Link>
          </div>
        </div>

        {recentScans.length > 0 ? (
          <div className="overflow-x-auto">
            <table className="table">
              <thead>
                <tr>
                  <th>Scan ID</th>
                  <th>Date/Time</th>
                  <th>Engine</th>
                  <th>Checks</th>
                  <th>Findings</th>
                  <th>Status</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {recentScans.map((scan) => (
                  <tr key={scan.id}>
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
                    <td>
                      <div className="flex items-center gap-2">
                        {getStatusIcon(scan.status)}
                        <span className="text-sm capitalize">{scan.status}</span>
                      </div>
                    </td>
                    <td>
                      <div className="flex items-center gap-2">
                        <Link
                          to={`/scans?scanId=${scan.id}`}
                          className="btn-secondary text-sm px-2 py-1"
                          title="View scan details"
                        >
                          <Eye className="w-3 h-3" />
                        </Link>
                        <button
                          onClick={() => handleDownloadScan(scan.id, 'json')}
                          className="btn-secondary text-sm px-2 py-1"
                          title="Download scan"
                        >
                          <Download className="w-3 h-3" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="text-center py-8 text-text-secondary">
            <Clock className="w-12 h-12 mx-auto mb-4 opacity-50" />
            <p>No recent scans found</p>
          </div>
        )}
      </div>

      {/* Quick Actions */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <Link to="/scans" className="btn-primary text-center py-3">
          <Play className="w-5 h-5 inline-block mr-2" />
          Run Full Suite
        </Link>
        <Link to="/scans?category=Kerberos_Security" className="btn-secondary text-center py-3">
          <SvgIcon name="surveillance-defense" size={20} className="inline-block mr-2 text-accent-primary" />
          Kerberos Checks
        </Link>
        <Link to="/scans?category=Privileged_Access" className="btn-secondary text-center py-3">
          <AlertTriangle className="w-5 h-5 inline-block mr-2" />
          Privileged Access
        </Link>
        <Link to="/reports" className="btn-secondary text-center py-3">
          <Eye className="w-5 h-5 inline-block mr-2" />
          View Reports
        </Link>
      </div>
    </div>
  );
};

export default Dashboard;
