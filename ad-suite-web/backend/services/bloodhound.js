const axios = require('axios');

/**
 * BloodHound integration service
 * Supports both BloodHound CE and Legacy 4.x
 */

/**
 * Test connection to BloodHound instance
 */
async function testConnection(config) {
  const { url, username, password, version } = config;

  try {
    const endpoint = version === 'CE' ? `${url}/api/v2/self` : `${url}/api/version`;
    const auth = Buffer.from(`${username}:${password}`).toString('base64');

    const response = await axios.get(endpoint, {
      headers: {
        'Authorization': `Basic ${auth}`,
        'Content-Type': 'application/json'
      },
      timeout: 10000,
      validateStatus: (status) => status < 500 // Accept 4xx as valid responses
    });

    if (response.status === 200 || response.status === 401) {
      // 401 means server is reachable but auth failed
      if (response.status === 401) {
        return { connected: false, error: 'Authentication failed - check username/password' };
      }
      return { connected: true, version: response.data };
    }

    return { connected: false, error: `Unexpected status: ${response.status}` };
  } catch (error) {
    console.error('BloodHound connection test failed:', error.message);

    if (error.code === 'ECONNREFUSED') {
      return { connected: false, error: 'Connection refused - is BloodHound running?' };
    }

    if (error.code === 'ETIMEDOUT') {
      return { connected: false, error: 'Connection timeout - check URL and network' };
    }

    return {
      connected: false,
      error: error.response?.data?.message || error.message
    };
  }
}

/**
 * Push findings to BloodHound
 * Converts AD findings to BloodHound-compatible format
 */
async function pushFindings(findings, config) {
  const { url, username, password, version } = config;

  try {
    // Convert findings to BloodHound format
    const bhData = convertFindingsToBloodHound(findings);

    const endpoint = version === 'CE'
      ? `${url}/api/v2/ingest`
      : `${url}/api/upload`;

    const auth = Buffer.from(`${username}:${password}`).toString('base64');

    const response = await axios.post(endpoint, bhData, {
      headers: {
        'Authorization': `Basic ${auth}`,
        'Content-Type': 'application/json'
      },
      timeout: 60000 // 60 second timeout for large datasets
    });

    return {
      pushed: true,
      count: bhData.data?.length || 0,
      response: response.data
    };
  } catch (error) {
    console.error('BloodHound push failed:', error.message);

    return {
      pushed: false,
      error: error.response?.data?.message || error.message
    };
  }
}

/**
 * Convert AD Security Suite findings to BloodHound JSON format
 * Maps findings to BloodHound nodes and edges
 */
function convertFindingsToBloodHound(findings) {
  const nodes = [];
  const edges = [];
  const nodeMap = new Map(); // Track unique nodes

  findings.forEach(finding => {
    try {
      const details = JSON.parse(finding.details_json || '{}');

      // Extract DN components
      const dn = finding.distinguished_name || details.DistinguishedName || '';
      const name = finding.name || details.Name || details.SamAccountName || '';

      if (!name || !dn) return; // Skip if no identifiable information

      // Determine object type from DN or check category
      const objectType = determineObjectType(dn, finding.category, details);

      // Create node if not already added
      const nodeId = `${name}@${extractDomain(dn)}`.toUpperCase();
      if (!nodeMap.has(nodeId)) {
        nodes.push({
          ObjectIdentifier: nodeId,
          Properties: {
            name: name,
            distinguishedname: dn,
            domain: extractDomain(dn),
            highvalue: finding.severity === 'CRITICAL' || finding.severity === 'HIGH',
            description: `${finding.check_name} - ${finding.severity}`,
            ...extractAdditionalProperties(details)
          },
          Aces: [],
          ObjectType: objectType,
          IsDeleted: false,
          IsACLProtected: details.adminCount === 1 || details.AdminCount === 1
        });
        nodeMap.set(nodeId, true);
      }

      // Create edges based on finding type
      const relationshipEdges = createRelationshipEdges(finding, details, nodeId);
      edges.push(...relationshipEdges);

    } catch (error) {
      console.error('Error converting finding to BloodHound format:', error);
    }
  });

  return {
    meta: {
      type: "domains",
      count: nodes.length,
      version: 5
    },
    data: nodes.map(node => ({
      ...node,
      Edges: edges.filter(e => e.source === node.ObjectIdentifier || e.target === node.ObjectIdentifier)
    }))
  };
}

/**
 * Determine BloodHound object type from DN and category
 */
function determineObjectType(dn, category, details) {
  const dnLower = dn.toLowerCase();

  // Check for computer accounts
  if (dnLower.includes('cn=computers') || dnLower.endsWith('$') ||
    category.includes('Computer') || category.includes('Domain_Controllers')) {
    return 'Computer';
  }

  // Check for groups
  if (dnLower.includes('cn=groups') || dnLower.includes('ou=groups') ||
    category.includes('Group') || details.objectClass === 'group') {
    return 'Group';
  }

  // Check for OUs
  if (dnLower.startsWith('ou=')) {
    return 'OU';
  }

  // Check for GPOs
  if (category.includes('Group_Policy') || category.includes('GPO')) {
    return 'GPO';
  }

  // Check for domains
  if (dnLower.startsWith('dc=') && !dnLower.includes('cn=')) {
    return 'Domain';
  }

  // Default to User
  return 'User';
}

/**
 * Extract domain from DN
 */
function extractDomain(dn) {
  const dcParts = dn.match(/DC=([^,]+)/gi);
  if (dcParts) {
    return dcParts.map(dc => dc.substring(3)).join('.').toUpperCase();
  }
  return 'UNKNOWN.LOCAL';
}

/**
 * Extract additional properties from finding details
 */
function extractAdditionalProperties(details) {
  const props = {};

  if (details.SamAccountName) props.samaccountname = details.SamAccountName;
  if (details.Enabled !== undefined) props.enabled = details.Enabled;
  if (details.LastLogon) props.lastlogon = details.LastLogon;
  if (details.PasswordLastSet) props.pwdlastset = details.PasswordLastSet;
  if (details.ServicePrincipalName) props.serviceprincipalnames = [details.ServicePrincipalName];
  if (details.MemberOf) props.memberof = Array.isArray(details.MemberOf) ? details.MemberOf : [details.MemberOf];

  return props;
}

/**
 * Create relationship edges based on finding type
 */
function createRelationshipEdges(finding, details, sourceNodeId) {
  const edges = [];

  // Group membership relationships
  if (details.MemberOf) {
    const groups = Array.isArray(details.MemberOf) ? details.MemberOf : [details.MemberOf];
    groups.forEach(groupDn => {
      const groupName = extractNameFromDn(groupDn);
      if (groupName) {
        edges.push({
          source: sourceNodeId,
          target: `${groupName}@${extractDomain(groupDn)}`.toUpperCase(),
          label: 'MemberOf',
          isInherited: false
        });
      }
    });
  }

  // Delegation relationships
  if (finding.check_id.includes('Delegation') || finding.check_id.includes('RBCD')) {
    edges.push({
      source: sourceNodeId,
      target: extractDomain(finding.distinguished_name),
      label: 'AllowedToDelegate',
      isInherited: false
    });
  }

  // Admin relationships
  if (finding.category.includes('Privileged') || details.adminCount === 1) {
    edges.push({
      source: sourceNodeId,
      target: 'DOMAIN ADMINS@' + extractDomain(finding.distinguished_name),
      label: 'MemberOf',
      isInherited: false
    });
  }

  return edges;
}

/**
 * Extract name from DN
 */
function extractNameFromDn(dn) {
  const match = dn.match(/CN=([^,]+)/i);
  return match ? match[1] : null;
}

module.exports = {
  testConnection,
  pushFindings,
  convertFindingsToBloodHound
};
