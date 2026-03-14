// Severity color mappings
export const severityColors = {
  critical: 'bg-severity-critical',
  high: 'bg-severity-high',
  medium: 'bg-severity-medium',
  low: 'bg-severity-low',
  info: 'bg-severity-info',
};

export const severityTextColors = {
  critical: 'text-severity-critical',
  high: 'text-severity-high',
  medium: 'text-severity-medium',
  low: 'text-severity-low',
  info: 'text-severity-info',
};

export const severityBorderColors = {
  critical: 'border-severity-critical',
  high: 'border-severity-high',
  medium: 'border-severity-medium',
  low: 'border-severity-low',
  info: 'border-severity-info',
};

// Status badge colors
export const statusColors = {
  running: 'bg-blue-500',
  completed: 'bg-green-500',
  failed: 'bg-red-500',
  aborted: 'bg-orange-500',
  pending: 'bg-gray-500',
};

// Risk score colors (1-10 scale)
export const getRiskScoreColor = (score) => {
  if (score >= 8) return 'text-severity-critical';
  if (score >= 6) return 'text-severity-high';
  if (score >= 4) return 'text-severity-medium';
  if (score >= 2) return 'text-severity-low';
  return 'text-severity-info';
};

export const getRiskScoreBgColor = (score) => {
  if (score >= 8) return 'bg-severity-critical';
  if (score >= 6) return 'bg-severity-high';
  if (score >= 4) return 'bg-severity-medium';
  if (score >= 2) return 'bg-severity-low';
  return 'bg-severity-info';
};

// Chart colors
export const chartColors = {
  critical: '#c0392b',
  high: '#e07b39',
  medium: '#d4a96a',
  low: '#4e8c5f',
  info: '#5b7fa6',
};

export const severityChartColors = [
  chartColors.critical,
  chartColors.high,
  chartColors.medium,
  chartColors.low,
  chartColors.info,
];

// Utility functions
export const getSeverityColor = (severity) => {
  return severityColors[severity?.toLowerCase()] || severityColors.info;
};

export const getSeverityTextColor = (severity) => {
  return severityTextColors[severity?.toLowerCase()] || severityTextColors.info;
};

export const getSeverityBorderColor = (severity) => {
  return severityBorderColors[severity?.toLowerCase()] || severityBorderColors.info;
};

export const getStatusColor = (status) => {
  return statusColors[status?.toLowerCase()] || statusColors.pending;
};
