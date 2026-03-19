import React, { useState } from 'react';
import { ChevronDown, ChevronRight, Info, ExternalLink } from 'lucide-react';
import { getSeverityColor, getSeverityTextColor, getSeverityBorderColor } from '../lib/colours';

const FindingsTable = ({ findings, loading, filters, onFiltersChange }) => {
  const [expandedRows, setExpandedRows] = useState(new Set());

  const toggleRowExpansion = (findingId) => {
    const newExpanded = new Set(expandedRows);
    if (newExpanded.has(findingId)) {
      newExpanded.delete(findingId);
    } else {
      newExpanded.add(findingId);
    }
    setExpandedRows(newExpanded);
  };

  const formatDetails = (detailsJson) => {
    try {
      const details = typeof detailsJson === 'string' ? JSON.parse(detailsJson) : detailsJson;
      return Object.entries(details).map(([key, value]) => (
        <div key={key} className="grid grid-cols-3 gap-2 py-1">
          <div className="text-text-secondary text-sm">{key}:</div>
          <div className="col-span-2 text-text-primary text-sm break-all">
            {typeof value === 'object' ? JSON.stringify(value, null, 2) : String(value)}
          </div>
        </div>
      ));
    } catch (error) {
      return <div className="text-text-secondary text-sm">Unable to parse details</div>;
    }
  };

  const severityOrder = { critical: 0, high: 1, medium: 2, low: 3, info: 4 };

  const sortedFindings = [...(findings || [])].sort((a, b) => {
    const severityDiff = severityOrder[a.severity?.toLowerCase()] - severityOrder[b.severity?.toLowerCase()];
    if (severityDiff !== 0) return severityDiff;

    const riskDiff = (b.riskScore || 0) - (a.riskScore || 0);
    if (riskDiff !== 0) return riskDiff;

    return a.checkName?.localeCompare(b.checkName) || 0;
  });

  if (loading) {
    return (
      <div className="space-y-3">
        {[...Array(5)].map((_, i) => (
          <div key={i} className="skeleton h-16 rounded-lg"></div>
        ))}
      </div>
    );
  }

  if (!findings || findings.length === 0) {
    return (
      <div className="text-center py-12 text-text-secondary">
        <Info className="w-12 h-12 mx-auto mb-4 opacity-50" />
        <p>No findings found</p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {/* Filters */}
      {onFiltersChange && (
        <div className="flex flex-wrap gap-2 p-4 bg-bg-tertiary rounded-lg">
          <span className="text-text-secondary self-center">Filter by severity:</span>
          {['critical', 'high', 'medium', 'low', 'info'].map(severity => (
            <button
              key={severity}
              onClick={() => onFiltersChange({
                ...filters,
                severity: filters?.severity?.includes(severity)
                  ? filters.severity.filter(s => s !== severity)
                  : [...(filters?.severity || []), severity]
              })}
              className={`severity-badge severity-${severity} ${filters?.severity?.includes(severity) ? 'ring-2 ring-accent-primary' : ''
                }`}
            >
              {severity.toUpperCase()}
            </button>
          ))}
        </div>
      )}

      {/* Table */}
      <div className="overflow-x-auto">
        <table className="table">
          <thead>
            <tr>
              <th className="w-8"></th>
              <th>Check ID</th>
              <th>Category</th>
              <th>Severity</th>
              <th>Name</th>
              <th>Distinguished Name</th>
              <th>Risk</th>
              <th>MITRE</th>
            </tr>
          </thead>
          <tbody>
            {sortedFindings.map((finding) => (
              <React.Fragment key={finding.id}>
                <tr
                  className="cursor-pointer hover:bg-bg-surface transition-colors"
                  style={{
                    borderLeft: `3px solid ${finding.severity === 'critical' ? '#c0392b' :
                      finding.severity === 'high' ? '#e07b39' :
                        finding.severity === 'medium' ? '#d4a96a' :
                          finding.severity === 'low' ? '#4e8c5f' : '#5b7fa6'
                      }`
                  }}
                  onClick={() => toggleRowExpansion(finding.id)}
                >
                  <td>
                    <button className="text-text-secondary hover:text-text-primary">
                      {expandedRows.has(finding.id) ? (
                        <ChevronDown className="w-4 h-4" />
                      ) : (
                        <ChevronRight className="w-4 h-4" />
                      )}
                    </button>
                  </td>
                  <td className="font-mono text-accent-primary text-sm">
                    {finding.checkId}
                  </td>
                  <td className="text-sm">
                    {finding.category?.replace(/_/g, ' ')}
                  </td>
                  <td>
                    <span className={`severity-badge severity-${finding.severity?.toLowerCase()}`}>
                      {finding.severity?.toUpperCase()}
                    </span>
                  </td>
                  <td className="max-w-xs truncate" title={finding.name}>
                    {finding.name || finding.checkName}
                  </td>
                  <td className="font-mono text-sm max-w-xs truncate" title={finding.distinguishedName}>
                    {finding.distinguishedName || 'N/A'}
                  </td>
                  <td>
                    <span className={`font-semibold ${getRiskScoreColor(finding.riskScore)}`}>
                      {finding.riskScore || 1}/10
                    </span>
                  </td>
                  <td className="font-mono text-sm">
                    {finding.mitre || 'N/A'}
                  </td>
                </tr>

                {expandedRows.has(finding.id) && (
                  <tr>
                    <td colSpan="8" className="bg-bg-surface">
                      <div className="p-4 space-y-3">
                        <div className="grid grid-cols-2 gap-4 text-sm">
                          <div>
                            <span className="text-text-secondary">Check Name:</span>
                            <div className="text-text-primary font-medium">
                              {finding.checkName}
                            </div>
                          </div>
                          <div>
                            <span className="text-text-secondary">Risk Score:</span>
                            <div className={`font-semibold ${getRiskScoreColor(finding.riskScore)}`}>
                              {finding.riskScore || 1}/10
                            </div>
                          </div>
                        </div>

                        {finding.distinguishedName && (
                          <div>
                            <span className="text-text-secondary text-sm">Distinguished Name:</span>
                            <div className="font-mono text-sm text-text-primary break-all mt-1">
                              {finding.distinguishedName}
                            </div>
                          </div>
                        )}

                        {finding.details_json && (
                          <div>
                            <span className="text-text-secondary text-sm">Additional Details:</span>
                            <div className="mt-2 space-y-1">
                              {formatDetails(finding.details_json)}
                            </div>
                          </div>
                        )}

                        <div className="text-xs text-text-muted pt-2 border-t border-border">
                          Created: {new Date(finding.created_at).toLocaleString()}
                        </div>
                      </div>
                    </td>
                  </tr>
                )}
              </React.Fragment>
            ))}
          </tbody>
        </table>
      </div>

      {/* Summary */}
      <div className="flex justify-between items-center p-4 bg-bg-tertiary rounded-lg">
        <div className="text-sm text-text-secondary">
          Showing {sortedFindings.length} findings
        </div>
        <div className="flex gap-4 text-sm">
          {Object.entries(
            sortedFindings.reduce((acc, f) => {
              acc[f.severity] = (acc[f.severity] || 0) + 1;
              return acc;
            }, {})
          ).map(([severity, count]) => (
            <span key={severity} className="flex items-center gap-1">
              <span className={`w-2 h-2 rounded-full bg-severity-${severity}`}></span>
              <span className="text-text-secondary">{severity}: {count}</span>
            </span>
          ))}
        </div>
      </div>
    </div>
  );
};

export default FindingsTable;
