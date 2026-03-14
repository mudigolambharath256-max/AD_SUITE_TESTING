const API_BASE = '/api';

// Generic API helper
const apiRequest = async (endpoint, options = {}) => {
  const url = `${API_BASE}${endpoint}`;
  const config = {
    headers: {
      'Content-Type': 'application/json',
      ...options.headers,
    },
    ...options,
  };

  if (config.body && typeof config.body === 'object') {
    config.body = JSON.stringify(config.body);
  }

  const response = await fetch(url, config);

  if (!response.ok) {
    const error = await response.json().catch(() => ({ error: 'Unknown error' }));
    throw new Error(error.error || `HTTP ${response.status}`);
  }

  return response.json();
};

// Health and system
export const getHealth = () => apiRequest('/health');
export const getCategories = () => apiRequest('/categories');

// Scan operations
export const runScan = (scanConfig) => apiRequest('/scan/run', {
  method: 'POST',
  body: scanConfig,
});

export const getScanStatus = (scanId) => apiRequest(`/scan/status/${scanId}`);

export const abortScan = (scanId) => apiRequest(`/scan/abort/${scanId}`, {
  method: 'POST',
});

export const getRecentScans = (limit = 20) =>
  apiRequest(`/scan/recent${limit ? `?limit=${limit}` : ''}`);

export const getFindings = (scanId, page = 1, limit = 50, filters = {}) => {
  const params = new URLSearchParams({
    page: page.toString(),
    limit: limit.toString(),
  });

  Object.entries(filters).forEach(([key, value]) => {
    if (value !== null && value !== undefined) {
      if (Array.isArray(value)) {
        value.forEach(v => params.append(key, v));
      } else {
        params.append(key, value);
      }
    }
  });

  return apiRequest(`/scan/${scanId}/findings?${params.toString()}`);
};

// Dashboard
export const getSeveritySummary = () => apiRequest('/dashboard/severity-summary');
export const getCategorySummary = () => apiRequest('/dashboard/category-summary');

// Reports and exports
export const exportScan = (scanId, format) => {
  return fetch(`${API_BASE}/reports/export`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ scanIds: [scanId], format }),
  }).then(response => {
    if (!response.ok) {
      throw new Error('Export failed');
    }
    return response.blob();
  });
};

export const exportMultipleScans = (scanIds, format) => {
  return fetch(`${API_BASE}/reports/export`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ scanIds, format }),
  }).then(response => {
    if (!response.ok) {
      throw new Error('Export failed');
    }
    return response.blob();
  });
};

// Integrations
export const testBloodHoundConnection = (config) =>
  apiRequest('/integrations/bloodhound/test', {
    method: 'GET',
    headers: { params: config } // Will be converted to query params
  });

export const pushToBloodHound = (scanId, config) =>
  apiRequest('/integrations/bloodhound/push', {
    method: 'POST',
    body: { scanId, config },
  });

export const testNeo4jConnection = (config) =>
  apiRequest('/integrations/neo4j/test', {
    method: 'GET',
    headers: { params: config }
  });

export const pushToNeo4j = (scanId, config) =>
  apiRequest('/integrations/neo4j/push', {
    method: 'POST',
    body: { scanId, config },
  });

export const testMCPConnection = (config) =>
  apiRequest('/integrations/mcp/test', {
    method: 'GET',
    headers: { params: config }
  });

export const pushToMCP = (scanId, config) =>
  apiRequest('/integrations/mcp/push', {
    method: 'POST',
    body: { scanId, config },
  });

// Schedules
export const getSchedules = () => apiRequest('/schedules');

export const createSchedule = (schedule) => apiRequest('/schedules', {
  method: 'POST',
  body: schedule,
});

export const updateSchedule = (id, updates) => apiRequest(`/schedules/${id}`, {
  method: 'PUT',
  body: updates,
});

export const deleteSchedule = (id) => apiRequest(`/schedules/${id}`, {
  method: 'DELETE',
});

export const runSchedule = (id) => apiRequest(`/schedules/${id}/run`, {
  method: 'POST',
});

// Settings
export const getSetting = (key) => apiRequest(`/settings/${key}`);

export const setSetting = (key, value) => apiRequest('/settings', {
  method: 'POST',
  body: { key, value },
});

// LLM Analysis
export const analyzeWithLLM = (findings, provider, apiKey, model) =>
  apiRequest('/llm/analyse', {
    method: 'POST',
    body: { findings, provider, apiKey, model },
  });

// SSE connection for scan progress
export const createScanStream = (scanId, onMessage, onError) => {
  const eventSource = new EventSource(`${API_BASE}/scan/stream/${scanId}`);

  eventSource.onmessage = (event) => {
    try {
      const data = JSON.parse(event.data);
      onMessage(data);
    } catch (error) {
      console.error('Error parsing SSE message:', error);
    }
  };

  eventSource.onerror = (error) => {
    console.error('SSE error:', error);
    if (onError) onError(error);
  };

  return eventSource;
};
