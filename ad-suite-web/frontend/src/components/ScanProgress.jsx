import React from 'react';
import { AlertCircle, CheckCircle, XCircle, Clock } from 'lucide-react';
import { getStatusColor } from '../lib/colours';

const ScanProgress = ({ scan, progress, logs = [] }) => {
  const getStatusIcon = (status) => {
    switch (status) {
      case 'running':
        return <Clock className="w-4 h-4 animate-pulse" />;
      case 'completed':
        return <CheckCircle className="w-4 h-4" />;
      case 'failed':
      case 'aborted':
        return <XCircle className="w-4 h-4" />;
      default:
        return <Clock className="w-4 h-4" />;
    }
  };

  const getStatusText = (status) => {
    switch (status) {
      case 'running':
        return 'Scanning';
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      case 'aborted':
        return 'Aborted';
      default:
        return 'Pending';
    }
  };

  const getProgressPercentage = () => {
    if (!progress || progress.total === 0) return 0;
    return Math.round((progress.progress / progress.total) * 100);
  };

  return (
    <div className="card">
      {/* Header */}
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-3">
          {getStatusIcon(scan?.status || progress?.status)}
          <h3 className="font-semibold text-text-primary">
            {getStatusText(scan?.status || progress?.status)}
          </h3>
          {progress?.status === 'running' && (
            <span className="w-2 h-2 bg-blue-500 rounded-full animate-pulse"></span>
          )}
        </div>
        
        {scan?.id && (
          <span className="text-sm text-text-secondary font-mono">
            {scan.id.substring(0, 8)}...
          </span>
        )}
      </div>

      {/* Progress Bar */}
      {progress && progress.total > 0 && (
        <div className="mb-4">
          <div className="flex items-center justify-between text-sm text-text-secondary mb-2">
            <span>Progress</span>
            <span>{progress.progress} / {progress.total} checks</span>
          </div>
          <div className="progress-bar">
            <div 
              className="progress-fill"
              style={{ width: `${getProgressPercentage()}%` }}
            ></div>
          </div>
          <div className="flex items-center justify-between text-sm text-text-secondary mt-2">
            <span>{getProgressPercentage()}% complete</span>
            {progress.findingCount !== undefined && (
              <span>{progress.findingCount} findings</span>
            )}
          </div>
        </div>
      )}

      {/* Current Check (if running) */}
      {progress?.status === 'running' && progress.currentCheck && (
        <div className="mb-4 p-3 bg-bg-tertiary rounded-lg">
          <div className="text-sm text-text-secondary mb-1">Currently Running:</div>
          <div className="font-mono text-accent-primary">
            {progress.currentCheck}
          </div>
        </div>
      )}

      {/* Scan Info */}
      {scan && (
        <div className="grid grid-cols-2 gap-4 mb-4 text-sm">
          <div>
            <span className="text-text-secondary">Engine:</span>
            <span className="ml-2 text-text-primary font-medium">{scan.engine}</span>
          </div>
          <div>
            <span className="text-text-secondary">Checks:</span>
            <span className="ml-2 text-text-primary font-medium">{scan.checkCount}</span>
          </div>
          {scan.duration && scan.duration > 0 && (
            <div>
              <span className="text-text-secondary">Duration:</span>
              <span className="ml-2 text-text-primary font-medium">
                {Math.round(scan.duration / 1000)}s
              </span>
            </div>
          )}
          {scan.findingCount !== undefined && (
            <div>
              <span className="text-text-secondary">Findings:</span>
              <span className="ml-2 text-text-primary font-medium">{scan.findingCount}</span>
            </div>
          )}
        </div>
      )}

      {/* Terminal Log */}
      {logs.length > 0 && (
        <div className="mt-4">
          <div className="text-sm text-text-secondary mb-2">Output Log:</div>
          <div className="bg-bg-primary border border-border rounded-lg p-3 h-48 overflow-y-auto font-mono text-xs">
            {logs.map((log, index) => (
              <div key={index} className="text-text-secondary mb-1">
                <span className="text-text-muted">
                  [{new Date(log.timestamp).toLocaleTimeString()}]
                </span>{' '}
                {log.message}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Error Display */}
      {scan?.status === 'failed' && (
        <div className="mt-4 p-3 bg-severity-critical/10 border border-severity-critical/30 rounded-lg">
          <div className="flex items-center gap-2 text-severity-critical">
            <AlertCircle className="w-4 h-4" />
            <span className="font-medium">Scan Failed</span>
          </div>
          {scan.error && (
            <div className="mt-2 text-sm text-text-secondary">
              {scan.error}
            </div>
          )}
        </div>
      )}
    </div>
  );
};

export default ScanProgress;
